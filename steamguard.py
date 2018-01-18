# Reimplementation of the Steam Mobile Authentication protocol, as demonstrated
# by https://github.com/geel9/SteamAuth (MIT-licensed, as is this code).
# Full functionality requires the 'requests' and 'rsa' modules, which should be
# available via pip. Some features will be available without them.

import base64
import hashlib
import hmac
import json
import time
# import requests # Not done globally as it's big and not all calls require it
# import rsa # Not done globally as it's third-party and very few actions need it

_time_offset = None # TODO: Align clocks with Valve

def get_default_user():
	print("TODO: check if there's exactly one user, and if so,")
	print("default to that user. Not yet implemented.")
	raise SystemExit

def timecheck():
	url = "https://api.steampowered.com/ITwoFactorService/QueryTime/v0001"
	import requests # ImportError? Install 'requests' using pip or similar.
	data = requests.post(url, "steamid=0").json()
	return int(data["response"]["server_time"]) - int(time.time())

def do_timecheck(user):
	"""Check your clock against Valve's"""
	offset = timecheck()
	if offset == 0:
		print("Your clock is in sync with Valve's (+/- 0.5 sec)")
	elif -3 < offset < 3:
		# A tiny offset is unlikely to cause issues. TODO: Figure out
		# how far out the clocks can be and still not be a problem.
		print("Your clock is in sync with Valve's (%+d sec)" % offset)
	else:
		print("CAUTION: Your clock is %+d sec out of sync" % offset)
		print("Consider adjusting your clock, or use --time-sync")

def generate_code(secret, timestamp=None):
	"""Generate a SteamGuard code for a given shared secret

	If timestamp is None, will generate one for the current
	time; otherwise it should be a Unix time.

	>>> generate_code("HvveV1y11i/lGOqBWdo3a1fU/290", 1516187198)
	"2K3V8"
	"""
	secret = base64.b64decode(secret)
	if timestamp is None:
		timestamp = int(time.time())
	timestamp //= 30 # The code regenerates every half minute
	timestamp = timestamp.to_bytes(8, "big")
	hash = hmac.new(secret, timestamp, hashlib.sha1).digest()
	# The low four bits of the last byte tell us where to grab four bytes from.
	b = hash[-1] & 15
	quad = hash[b:b+4]
	# The code seems to be masked off to 31-bit (??)
	code = int.from_bytes(quad, "big") & 0x7FFFFFFF
	alphabet = "23456789BCDFGHJKMNPQRTVWXY"
	ret = ""
	for _ in range(5):
		ret += alphabet[code % 26]
		code //= 26
	return ret

def do_code(user):
	"""Generate an auth code for logins"""
	# TODO: Retrieve the saved shared-secret, decode it if necessary,
	# and call generate_code on that secret.
	print(generate_code(user)) # HACK: Provide the secret itself for now
	if not user: user = get_default_user()
	print("Stub, unimplemented")

def do_trade(user):
	"""Accept all pending trades/markets"""
	if not user: user = get_default_user()
	print("Stub, unimplemented")

def do_setup(user):
	"""Set up a new user"""
	if not user:
		user = input("User name: ")
		if not user: return
	import getpass
	password = getpass.getpass()
	import requests # ImportError? Install 'requests' and 'rsa' using pip or similar.
	data = requests.post("https://steamcommunity.com/login/getrsakey", {"username": user}).json()
	import rsa # ImportError? 'pip install rsa' or equivalent.
	key = rsa.PublicKey(int(data["publickey_mod"], 16),
		int(data["publickey_exp"], 16))
	password = password.encode("ascii") # Encoding error? See if Steam uses UTF-8.
	password = base64.b64encode(rsa.encrypt(password, key))
	params = {
		"username": user, "password": password,
		"rsatimestamp": data["timestamp"],
		"oauth_client_id": "DE45CD61",
		"oauth_scope": "read_profile write_profile read_client write_client",
		# Dunno if these values are needed
		#"loginfriendlyname": "#login_emailauth_friendlyname_mobile",
		#"remember_login": "false",
		#"donotcache": str(int(time.time())),
	}
	# This is a magic cookie in every sense. Its presence makes Steam provide
	# OAuth info, which otherwise is inexplicably omitted. Thanks, Steam! (I
	# could understand a query parameter or request body variable "mode=oauth"
	# or something, but doing it with a cookie? Seriously?)
	cookies = {"mobileClient": "android"}
	# Generate a sessionid (why this is necessary, I don't know)
	resp = requests.get("https://steamcommunity.com/login?oauth_client_id=DE45CD61&oauth_scope=read_profile%20write_profile%20read_client%20write_client",
		headers={"X-Requested-With": "com.valvesoftware.android.steam.community"}, cookies=cookies)
	cookies.update(resp.cookies)
	while "need more info":
		resp = requests.post("https://steamcommunity.com/login/dologin", params, cookies=cookies)
		cookies.update(resp.cookies)
		data = resp.json()
		if data["success"]: break # Yay!
		if data.get("emailauth_needed"):
			print("Email auth code required; check email at domain:", data["emaildomain"])
			params["emailsteamid"] = data["emailsteamid"]
			params["emailauth"] = input("Enter authorization code: ")
		elif data.get("requires_twofactor"):
			params["twofactorcode"] = input("Enter 2FA code: ")
		else:
			print("Unable to log in - here's the raw dump:")
			print(data)
			return
	import pprint; pprint.pprint(data)
	print()
	pprint.pprint(cookies)

	# See if there's already a phone associated with the account.
	# If there is, we should be able to receive an SMS there. I think.
	resp = requests.post("https://steamcommunity.com/steamguard/phoneajax",
		{"op": "has_phone", "arg": "null", "sessionid": cookies["sessionid"]},
		cookies=cookies)
	if not resp.json()["has_phone"]:
		print("There is no phone number associated with your account.")
		print("Provide a phone number that can receive an SMS, in the")
		print("format: +{CC} 123-456-789 (where {CC} is your country")
		print("code for international dialing)")
		phone = input("Enter your phone number: ")
		phone = phone.replace("-", "")
		resp = requests.post("https://steamcommunity.com/steamguard/phoneajax",
			{"op": "add_phone_number", "arg": phone, "sessionid": cookies["sessionid"]},
			cookies=cookies)
		pprint.pprint(resp.json())

	# For reasons which escape me, the OAuth info is provided as a *string*
	# that happens to be JSON-formatted. This is inside a JSON response
	# body. It could have simply been a nested object, but noooooo.
	oauth = json.loads(data["oauth"])
	resp = requests.post("https://api.steampowered.com/ITwoFactorService/AddAuthenticator/v0001", {
		"access_token": oauth["oauth_token"],
		"steamid": oauth["steamid"],
		"authenticator_type": "1",
		"device_identifier": "android:92bb3646-1d32-3646-3646-36461d32bdbe", # TODO: Generate randomly?
		"sms_phone_id": "1",
	})
	data = resp.json()
	print()
	pprint.pprint(data)

def usage():
	print("USAGE: python3 steamguard.py [command] [user]")
	print("command is one of:")
	for func in sorted(globals()):
		if func.startswith("do_"):
			doc = globals()[func].__doc__.split("\n")[0]
			print("%-10s %s" % (func[3:], doc))
	print("user is the name of the Steam account to use - optional if")
	print("only one account is registered with this app.")
	return 1

def main(args):
	func = user = None
	for arg in args:
		f = globals().get("do_" + arg)
		if f:
			if func: return usage()
			func = f
		else:
			if user: return usage()
			user = arg
	if not func: func = do_code
	func(user)

if __name__ == "__main__":
	import sys
	sys.exit(main(sys.argv[1:]))