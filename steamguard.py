# Reimplementation of the Steam Mobile Authentication protocol, as demonstrated
# by https://github.com/geel9/SteamAuth (MIT-licensed, as is this code).
# Full functionality requires the 'requests' and 'rsa' modules, which should be
# available via pip. Some features will be available without them.

import base64
import collections
import hashlib
import hmac
import json
import os
import threading
import time
import pprint
# import requests # Not done globally as it's big and not all calls require it
# import rsa # Not done globally as it's third-party and very few actions need it

_time_offset = None # TODO: Align clocks with Valve
DEBUG = False # Set to True to get raw dumps of responses

def colorprint(text, color):
	"""Display the given text in the given color.

	TODO: Check if the terminal can handle it, and if not, just
	print the text as-is.
	"""
	if not color:
		print(text)
		return
	color = int(color.strip("#"), 16)
	r = color >> 16
	g = (color >> 8) & 255
	b = color & 255
	print("\x1b[0;38;2;%d;%d;%dm%s\x1b[0m" % (r,g,b, text))

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

def saved_cookies_filename():
	# The cookies file can be deleted at any time.
	return saved_accounts_filename()[:-2] + "_cookies"

def load_users():
	global users, user_cookies
	try:
		with open(saved_accounts_filename()) as f:
			users = json.load(f)
	except FileNotFoundError:
		users = {}
	try:
		with open(saved_cookies_filename()) as f:
			user_cookies = json.load(f)
	except FileNotFoundError:
		# Note that it's perfectly reasonable to have a user file but
		# no cookies file. 2FA codes will work fine, but you'll need
		# to re-enter a password to do your first trade per account.
		user_cookies = {}
	if "" in users: del users[""]

def save_users():
	with open(saved_accounts_filename(), "w") as f:
		print("{", file=f)
		for username, info in users.items():
			if not username: continue
			# Compat: remove junk from previous save file formats
			if "account_name" in info: del info["account_name"]
			if "sessionid" in info: del info["sessionid"]
			if "steamLoginSecure" in info: del info["steamLoginSecure"]
			print("\t%s: %s," % (
				json.dumps(username),
				json.dumps(info),
			), file=f)
		# Since JSON doesn't like trailing commas, we add a
		# shim at the end.
		print('\t"": {}', file=f)
		print("}", file=f)
	with open(saved_cookies_filename(), "w") as f:
		json.dump(user_cookies, f)
		print("", file=f)
	# Attempt to mark the files as unreadable by anyone else
	os.chmod(saved_accounts_filename(), 0o600)
	os.chmod(saved_cookies_filename(), 0o600)
load_users()

def get_default_user():
	print("TODO: check if there's exactly one user, and if so,")
	print("default to that user. Not yet implemented.")
	raise SystemExit

def timecheck():
	import requests # ImportError? Install 'requests' using pip or similar.
	data = requests.post("https://api.steampowered.com/ITwoFactorService/QueryTime/v0001", "steamid=0").json()
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
			users[username] = {
				"identity_secret": info["identity_secret"],
				"shared_secret": info["shared_secret"],
				"revocation_code": info["revocation_code"],
				"steamid": info["Session"]["SteamID"],
			}
			user_cookies[username] = info["Session"]["SteamLoginSecure"]
			save_users()
			return info["shared_secret"]
	return None

def do_code(user):
	"""Generate an auth code for logins"""
	if user is not None and len(user) == 28:
		# Allow the secret itself to be provided on the
		# command line, for testing/debugging
		print(generate_code(user))
		return
	if not user: user = get_default_user()
	info = users.get(user)
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

def do_trade(username):
	"""Accept all pending trades/markets"""
	if not username: username = get_default_user()
	user = users.get(username)
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
		'steamLoginSecure': user_cookies[username],
	}
	try:
		info = requests.get("https://steamcommunity.com/mobileconf/conf", params, cookies=cookies)
	except requests.exceptions.InvalidSchema as e:
		# Probably we're not logged in.
		if e.args[0] == "No connection adapters were found for 'steammobile://lostauth'":
			print("Lost auth - rerun 'setup' on this user to refresh session")
			print("TODO: Attempt a session refresh within the API first")
			return
	# Now begins the parsing of HTML. Followed by a light salad.
	# It's a mess, it's not truly parsing HTML, and it's not pretty.
	# But it works. It gets the info we need. It's as good as we can
	# hope for without an actual API for doing this.
	ids = []; keys = []; trades = []
	# with open("dump.html", "w") as f: print(info.text, file=f)
	for raw in info.text.split('<div class="mobileconf_list_entry"')[1:]:
		tag, rest = raw.split(">", 1)
		confid = key = type = None
		for attr in tag.split(" "):
			if "=" not in attr: continue
			name, val = attr.split("=", 1)
			if name == "data-confid": confid = val.strip('"')
			if name == "data-key": key = val.strip('"')
			if name == "data-type": type = val.strip('"')
		if confid is None or key is None:
			print("UNABLE TO PARSE:")
			print(tag)
			continue
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
		if len(desc) != 3:
			print("Parsing problem - description may not be properly readable")
			print(desc)
			continue
		if type == "2":
			# Trade offer with another player
			# Show it over multiple lines for clarity
			desc[1] = desc[1].replace(", ", "\n\t")
			# Note that the items CAN include commas, which will make this display ugly.
			# (Try trading "Taunt: Rock, Paper, Scissors" for instance.)
			# The details view will still be correct.
		trades.append(desc)
	if not ids:
		print("No trades to confirm.")
		return
	#resp = requests.get("https://steamcommunity.com/mobileconf/details/" + ids[0], params, cookies=cookies)
	#with open("details.json", "w") as f: print(resp.text, file=f)
	#with open("details.html", "w") as f: print(resp.json()["html"], file=f)
	# TODO: Provide more details (on request, esp if it requires another API call)
	# TODO: Have a --dump flag to create the above dump files
	while "user input needed":
		print()
		for pos, desc in enumerate(trades):
			# The first description line usually says who you're trading with,
			# or what you're selling; the last line says when the offer was made.
			print("%d: %s (%s)" % (pos + 1, desc[0], desc[2].lower()))
			print("\t" + desc[1])
		cmd = input("Enter 'a' to accept all, or a transaction number for more details: ").lower()
		if not cmd:
			print("Trades left untouched.")
			return
		if cmd[0] == "a":
			params["op"] = "allow"
			params["cid[]"] = ids; params["ck[]"] = keys
			resp = requests.post("https://steamcommunity.com/mobileconf/multiajaxop", params, cookies=cookies)
			ok = resp.json()["success"]
			if ok:
				print("All transactions approved.")
				return
			print("Unable to do that - here's the response:")
			print(resp.json())
		elif cmd.isdigit():
			try: which = int(cmd) - 1
			except ValueError: continue
			if which < 0 or which >= len(ids):
				print("Not a transaction number I recognize - try again?")
				continue
			print("Downloading details...")
			resp = requests.get("https://steamcommunity.com/mobileconf/details/" + ids[which], params, cookies=cookies)
			# Yes, that's right. We get back a JSON blob that contains
			# a blob of HTML. Which contains JavaScript.
			print()
			html = resp.json()["html"]
			if "g_rgAppContextData" in html:
				# It's a market listing. Show the full details, with one more API call.
				html = html.split('<div class="mobileconf_listing_prices">', 1)[1]
				text, html = html.split("<script>", 1)
				# 'text' is now a block of (HTML-formatted) text that's interesting.
				# 'html' is the remaining HTML, which has some other stuff in it still.
				text = text.replace("<br>", "") # Join the lines with linebreaks.
				while text:
					cur, text = text.split('<', 1)
					cur = cur.strip()
					if cur: print(*cur.split()) # collapse whitespace
					if text: text = text.split('>', 1)[1].strip()
				# Okay. Now to parse out a block of info from the HTML...
				# that is to say, the JSON in the HTML in the JSON. Yeah.
				jsdata = html.split("BuildHover( 'confiteminfo', ", 1)[1]
				confiteminfo = json.JSONDecoder().raw_decode(jsdata)[0]
				for link in confiteminfo["actions"]:
					print(link["name"], link["link"])
				name = confiteminfo["name"]
				colorprint(name, confiteminfo.get("name_color"))
				print(confiteminfo["type"])
				if confiteminfo["market_name"] != name:
					print("Market name:", confiteminfo["market_name"])
				while "stay in details":
					print("d: Show more details for this listing")
					print("a: Accept just this listing, leaving others untouched")
					print("c: Cancel just this listing, leaving others untouched")
					cmd = input("Or hit Enter to return to the summary: ").lower()
					if cmd == "d":
						for line in confiteminfo["descriptions"]:
							colorprint(line["value"], line.get("color"))
						print()
					elif cmd == "c" or cmd == "a":
						params["op"] = "allow" if cmd == "a" else "cancel"
						params["cid"] = ids[which]; params["ck"] = keys[which]
						resp = requests.post("https://steamcommunity.com/mobileconf/ajaxop", params, cookies=cookies)
						ok = resp.json()["success"]
						if ok:
							# Abuse recursion because we have to reset basically EVERYTHING
							return do_trade(username)
						print("Unable to do that - here's the response:")
						print(resp.json())
					else:
						break
			else:
				# Split the HTML into two interesting parts:
				# 1) What you're offering
				# 2) What you're requesting
				_, offer, request = html.split("tradeoffer_item_list", 2)
				offer = [item.split('"', 1)[0] for item in offer.split('data-economy-item="')[1:]]
				request = [item.split('"', 1)[0] for item in request.split('data-economy-item="')[1:]]
				if not offer and not request:
					print("No items found in trade - probable parsing error")
					continue
				if not offer:
					print("You request %d item(s)" % len(request))
				elif not request:
					print("You offer %d item(s) as a gift" % len(offer))
				else:
					print("You offer %d item(s) and request %d item(s)" % (len(offer), len(request)))
				item_details = {}
				downloadme = collections.deque(offer + request)
				def download_item(item):
					ids = item.split("/", 1)[1]
					text = requests.get("https://steamcommunity.com/economy/itemclasshover/" + ids + "?content_only=1").text
					jsdata = text.split("BuildHover(")[1].split(",", 1)[1].strip()
					info = json.JSONDecoder().raw_decode(jsdata)[0]
					item_details[item] = info
				def display_item(item):
					info = item_details[item]
					colorprint("\t" + info["name"], info.get("name_color"))
					if "fraudwarnings" in info:
						# This also picks up "item has been renamed"
						for fraud in info["fraudwarnings"]:
							fraud = fraud.replace("This item has been renamed.\n", "")
							print("\t\t" + fraud)
					if info["market_name"] != info["name"]:
						# This shows extra details for some items, eg wear
						# level on war paint, killstreak quality, etc
						print("\t\t ==> " + info["market_name"])
					# TODO: Have some "warning flag" heuristics based on
					# info["description"] that would indicate stuff the user
					# would want to know, eg "Killstreaker", "Unusual", "Gift"
				def download_thread():
					while "moar stuff":
						try:
							item = downloadme.popleft()
						except IndexError:
							break
						download_item(item)
				# Cap out at eight download threads
				thread_count = min(len(offer) + len(request), 8)
				threads = [threading.Thread(target=download_thread) for _ in range(thread_count)]
				for thread in threads: thread.start()
				for thread in threads: thread.join()
				while "stay in details":
					if offer: print("<== You are offering ==>")
					for item in offer:
						display_item(item)
					if request: print("<== You are requesting ==>")
					for item in request:
						display_item(item)
					print()
					if offer: print("o: Show more details about the items offered")
					if request: print("r: Show more details about the items requested")
					print("a: Accept just this trade, leaving others untouched")
					print("c: Cancel just this trade, leaving others untouched")
					cmd = input("Or hit Enter to return to the summary: ").lower()
					if cmd == "o" or cmd == "r":
						items = offer if cmd == "o" else request
						if not items: continue
						pos = 0
						while "stay in item info":
							info = item_details[items[pos]]
							name = info["name"]
							colorprint(name, info.get("name_color"))
							print(info["type"])
							if info["market_name"] != name:
								print("Market name:", info["market_name"])
							for line in info["descriptions"]:
								colorprint(line["value"], line.get("color"))
							print()
							cmd = input("Item %d/%d, [n]ext/[p]rev, [q]uit this menu, or enter number: " %
								(pos + 1, len(items)))
							if cmd == "n":
								pos = (pos + 1) % len(items)
							elif cmd == "p":
								pos = (pos - 1) % len(items)
							elif cmd.isdigit():
								pos = (int(cmd) - 1) % len(items)
							elif cmd == "":
								# Paginate: advance to the next, but if at last item,
								# return to previous menu. Kinda DWIMmy but useful.
								if pos == len(items) - 1: break
								pos += 1
							elif cmd == "q":
								break
					elif cmd == "c" or cmd == "a":
						params["op"] = "allow" if cmd == "a" else "cancel"
						params["cid"] = ids[which]; params["ck"] = keys[which]
						resp = requests.post("https://steamcommunity.com/mobileconf/ajaxop", params, cookies=cookies)
						ok = resp.json()["success"]
						if ok:
							# Abuse recursion because we have to reset basically EVERYTHING
							return do_trade(username)
						print("Unable to do that - here's the response:")
						print(resp.json())
					else:
						break

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
				old_info = users.get(user)
				if old_info and old_info["shared_secret"]:
					params["twofactorcode"] = generate_code(old_info["shared_secret"])
					continue
			params["twofactorcode"] = input("Enter 2FA code: ")
		else:
			print("Unable to log in - here's the raw dump:")
			print(data)
			return
	if DEBUG:
		pprint.pprint(data)
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

	# TODO: See if there's a way to change auth rather than just delete and
	# start over, which incurs a 15-day trade lock. Not sure how; the C#
	# steamguard-cli has the same issue, where after revoking, no SMS comes.
	# Might require enlarging the scope of the 'while' loop.
	while "retry add auth":
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
			if user not in users:
				print("Something else is already authenticated, will need to remove.")
				print("You will need the 'recovery code' or 'revocation code' from")
				print("the mobile authenticator app or whatever other service you have")
				print("been using. If you do not have such a code, contact Valve.")
				print()
				revcode = input("Enter the revocation code eg R12345: ")
				if not revcode: return
				resp = requests.post("https://api.steampowered.com/ITwoFactorService/RemoveAuthenticator/v0001", {
					"steamid": oauth["steamid"],
					"steamguard_scheme": "2", # ?? dunno
					"revocation_code": revcode,
					"access_token": oauth["oauth_token"],
				}).json()["response"]
				if resp.get("success"):
					print("Success! Your old authenticator has been removed.")
					print("If you don't receive an SMS, restart the auth procedure.")
					continue
				print("Unable to remove the old auth - check the revocation code.")
				print(resp)
				return
			user_cookies[user] = cookies["steamLoginSecure"]
			save_users()
			print("Login data refreshed. Trades should work again.")
			return
		elif data["status"] == 1:
			# Success!
			break
		print("Steam authentication failed - here's the raw dump:")
		print()
		pprint.pprint(data)
		return
	identity_secret = data["identity_secret"]
	shared_secret = data["shared_secret"]
	revcode = data["revocation_code"]
	print("Revocation code:", revcode)
	print("RECORD THIS. Do it. Go.")
	users[user] = {
		"identity_secret": identity_secret,
		"shared_secret": shared_secret,
		"revocation_code": revcode,
		"steamid": oauth["steamid"],
	}
	user_cookies[user] = cookies["steamLoginSecure"]
	save_users()

	while True:
		code = input("Enter the SMS code sent to your phone: ")
		if verify_phone:
			data = requests.post("https://steamcommunity.com/steamguard/phoneajax",
				{"op": "check_sms_code", "arg": code, "checkfortos": 0,
				"skipvoip": 1, "sessionid": cookies["sessionid"]},
				cookies=cookies).json()
			print()
			if DEBUG: pprint.pprint(data)
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
		if DEBUG: pprint.pprint(data)
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
