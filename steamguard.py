# Reimplementation of the Steam Mobile Authentication protocol, as demonstrated
# by https://github.com/geel9/SteamAuth (MIT-licensed, as is this code).
# Full functionality requires the 'requests' and 'rsa' modules, which should be
# available via pip. Some features will be available without them.

import base64
import hashlib
import hmac
import json
import os
import time
# import requests # Not done globally as it's big and not all calls require it
# import rsa # Not done globally as it's third-party and very few actions need it

_time_offset = None # TODO: Align clocks with Valve

def saved_accounts_filename():
	HOME = os.environ.get("HOME")
	if HOME:
		# Unix-like system; save into ~/.steamguardrc
		return HOME + "/.steamguardrc"
	else:
		# Probably Windows; save into .steamguardrc in the
		# current directory instead. Depends on this script
		# being run consistently from the same directory.
		return ".steamguardrc"

def load_users():
	with open(saved_accounts_filename()) as f:
		users = json.load(f)
	if "" in users: del users[""]
	return users

def save_users(users):
	with open(saved_accounts_filename(), "w") as f:
		print("{", file=f)
		for username, info in users.items():
			if not username: continue
			if "account_name" in info: del info["account_name"]
			print("\t%s: %s," % (
				json.dumps(username),
				json.dumps(info),
			), file=f)
		# Since JSON doesn't like trailing commas, we add a
		# shim at the end.
		print('\t"": {}', file=f)
		print("}", file=f)

def load_users_legacy():
	users = {}
	with open(saved_accounts_filename()) as f:
		for line in f:
			line = line.strip()
			if not line: continue
			info = json.loads(line)
			users[info["account_name"]] = info
	# Automatically save back in the new format
	save_users(users)
	return users

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

def import_from_mafiles(username):
	"""Attempt to import one user from ~/maFiles, where the C# auth program puts it

	If successful, returns the shared secret for that account, and also
	saves it to our own file. If unsuccessful, returns None.
	"""
	HOME = os.environ.get("HOME")
	if not HOME: return None
	dir = HOME + "/maFiles"
	try:
		files = os.listdir(dir)
	except FileNotFoundError:
		return None
	for file in files:
		if file == "manifest.json": continue
		with open(dir + "/" + file) as f:
			info = json.load(f)
		if info["account_name"] == username:
			users = load_users()
			users[username] = {
				"account_name": username,
				"identity_secret": info["identity_secret"],
				"shared_secret": info["shared_secret"],
				"revocation_code": info["revocation_code"],
				"steamid": info["Session"]["SteamID"],
				"sessionid": info["Session"]["SessionID"],
				"steamLoginSecure": info["Session"]["SteamLoginSecure"],
			}
			save_users(users)
			return info["shared_secret"]
	return None

def get_user_info(username):
	try:
		users = load_users()
	except json.decoder.JSONDecodeError:
		users = load_users_legacy()
	return users.get(username)

def do_code(user):
	"""Generate an auth code for logins"""
	if user is not None and len(user) == 28:
		# Allow the secret itself to be provided on the
		# command line, for testing/debugging
		print(generate_code(user))
		return
	if not user: user = get_default_user()
	info = get_user_info(user)
	if info:
		print(generate_code(info["shared_secret"]))
		return
	# Not found. Look in ~/maFiles and see if we can import.
	secret = import_from_mafiles(user)
	if not secret:
		print("User not found, try running 'steamguard.py setup'")
		return
	print("==> imported shared secret from maFiles")
	print(generate_code(secret))

def generate_identity_hash(secret, tag, timestamp=None):
	"""Generate a hash based on the identity_secret"""
	secret = base64.b64decode(secret)
	if timestamp is None:
		timestamp = int(time.time())
	timestamp = timestamp.to_bytes(8, "big")
	hash = hmac.new(secret, timestamp + tag.encode("ascii"), hashlib.sha1).digest()
	return base64.b64encode(hash)

def do_trade(user):
	"""Accept all pending trades/markets"""
	if not user: user = get_default_user()
	user = get_user_info(user)
	if not user:
		print("User not found")
		return
	import requests
	tm = int(time.time())
	params = {
		"m": "android", "tag": "conf", "t": tm,
		"p": "android:92bb3646-1d32-3646-3646-36461d32bdbe",
		"a": user["steamid"],
		"k": generate_identity_hash(user["identity_secret"], "conf"),
	}
	cookies = {
		'steamLoginSecure': user["steamLoginSecure"],
	}
	info = requests.get("https://steamcommunity.com/mobileconf/conf", params, cookies=cookies)
	import pprint
	# Now begins the parsing of HTML. Followed by a light salad.
	# It's a mess, it's not truly parsing HTML, and it's not pretty.
	# But it works. It gets the info we need. It's as good as we can
	# hope for without an actual API for doing this.
	ids = []; keys = []
	for raw in info.text.split('<div class="mobileconf_list_entry"')[1:]:
		tag, rest = raw.split(">", 1)
		confid = key = None
		for attr in tag.split(" "):
			if "=" not in attr: continue
			name, val = attr.split("=", 1)
			if name == "data-confid": confid = val.strip('"')
			if name == "data-key": key = val.strip('"')
		if confid is None or key is None:
			print("UNABLE TO PARSE:")
			print(tag)
			continue
		print("confid", confid, "- key", key)
		ids.append(confid); keys.append(key)
		rest = rest.split('<div class="mobileconf_list_entry_sep">', 1)[0].strip()
		# Strip HTML tags and produce a series of text nodes,
		# ignoring any that are just whitespace
		desc = []
		while rest:
			text, rest = rest.split('<', 1)
			text = text.strip()
			if text: desc.append(text)
			if rest: rest = rest.split('>', 1)[1]
		print(desc)
	if not input("Enter 'a' to accept all: ").startswith("a"):
		print("Trades left untouched.")
		return
	params["op"] = "allow"
	params["cid[]"] = ids; params["ck[]"] = keys
	resp = requests.post("https://steamcommunity.com/mobileconf/multiajaxop", params, cookies=cookies)
	print(resp)
	import pprint; pprint.pprint(resp.json())

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
			if "twofactorcode" not in params:
				# Try to automate this if we already have part of the info
				old_info = get_user_info(user)
				if old_info and old_info["shared_secret"]:
					params["twofactorcode"] = generate_code(old_info["shared_secret"])
					continue
			params["twofactorcode"] = input("Enter 2FA code: ")
		else:
			print("Unable to log in - here's the raw dump:")
			print(data)
			return
	import pprint; pprint.pprint(data)
	print()
	pprint.pprint(cookies)
	# For reasons which escape me, the OAuth info is provided as a *string*
	# that happens to be JSON-formatted. This is inside a JSON response
	# body. It could have simply been a nested object, but noooooo.
	oauth = json.loads(data["oauth"])

	# See if there's already a phone associated with the account.
	# If there is, we should be able to receive an SMS there. I think.
	resp = requests.post("https://steamcommunity.com/steamguard/phoneajax",
		{"op": "has_phone", "arg": "null", "sessionid": cookies["sessionid"]},
		cookies=cookies)
	verify_phone = False
	if not resp.json()["has_phone"]:
		print("There is no phone number associated with your account.")
		print("Provide a phone number that can receive an SMS, in the")
		print("format: +{CC} 123-456-789 (where {CC} is your country")
		print("code for international dialing)")
		phone = input("Enter your phone number: ")
		phone = phone.replace("-", "")
		data = requests.post("https://steamcommunity.com/steamguard/phoneajax",
			{"op": "add_phone_number", "arg": phone, "sessionid": cookies["sessionid"]},
			cookies=cookies).json()
		if not data["success"]:
			print("Steam was unable to add that phone number.")
			print(data)
			return
		verify_phone = True

	data = requests.post("https://api.steampowered.com/ITwoFactorService/AddAuthenticator/v0001", {
		"access_token": oauth["oauth_token"],
		"steamid": oauth["steamid"],
		"authenticator_type": "1",
		"device_identifier": "android:92bb3646-1d32-3646-3646-36461d32bdbe", # TODO: Generate randomly?
		"sms_phone_id": "1",
	}).json()["response"]
	if data["status"] == 29:
		# Already using an authenticator. If that's ours, save the info back
		# and thus refresh the login. Otherwise, the other one may need to be
		# revoked before we can move on.
		users = load_users()
		if user not in users:
			print("Something else is already authenticated, will need to remove.")
			print("TODO.")
			return
		users[user]["steamLoginSecure"] = cookies["steamLoginSecure"]
		save_users(users)
		print("Login data refreshed. Trades should work again.")
		return
	elif data["status"] != 1:
		print("Steam authentication failed - here's the raw dump:")
		print()
		pprint.pprint(data)
	identity_secret = data["identity_secret"]
	shared_secret = data["shared_secret"]
	revcode = data["revocation_code"]
	print("Revocation code:", revcode)
	print("RECORD THIS. Do it. Go.")
	users = load_users()
	users[user] = {
		"account_name": user,
		"identity_secret": identity_secret,
		"shared_secret": shared_secret,
		"revocation_code": revcode,
		"steamid": oauth["steamid"],
		"sessionid": cookies["sessionid"], # might not be used for anything, not sure
		"steamLoginSecure": cookies["steamLoginSecure"],
	}
	save_users(users)

	while True:
		code = input("Enter the SMS code sent to your phone: ")
		if verify_phone:
			data = requests.post("https://steamcommunity.com/steamguard/phoneajax",
				{"op": "check_sms_code", "arg": code, "checkfortos": 0,
				"skipvoip": 1, "sessionid": cookies["sessionid"]},
				cookies=cookies).json()
			print()
			pprint.pprint(data)
			if not data["success"]: continue
			print("Phone successfully registered.")
			verify_phone = False
		tm = int(time.time())
		data = requests.post("https://api.steampowered.com/ITwoFactorService/FinalizeAddAuthenticator/v0001", {
			"access_token": oauth["oauth_token"],
			"steamid": oauth["steamid"],
			"activation_code": code,
			"authenticator_code": generate_code(shared_secret, tm),
			"authenticator_time": tm,
		}).json()["response"]
		if data["success"]: break
		pprint.pprint(data)
	print("Your phone has been registered. SAVE the revocation code.")
	print("If you lose the revocation code, you will have great difficulty")
	print("undoing what you've just done here.")

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
