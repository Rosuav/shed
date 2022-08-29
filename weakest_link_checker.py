# Read the log created by weakest_link.py and enhance the configs
import json
import re
import os
import urllib.parse
import requests
config = { }
try:
	with open("weakest_link.json") as f: config = json.load(f)
except FileNotFoundError: pass
for ensure in "redirects", "use_https", "known_links":
	if ensure not in config: config[ensure] = { }

handlers = { }
def handler(n):
	def wrapper(f):
		handlers[n] = f
		return f
	return wrapper

@handler("External link")
@handler("Non-encrypted link outside site")
def extlink(type, context, url, extra):
	# Add rules here for known patterns
	# TODO: http://www.cris.com/~oakapple/gasdisc/ --> http://www.gasdisc.oakapplepress.com/
	if url in config["known_links"]: return
	# Very very basic validation: if the server returns anything in the 200 range,
	# it's fine. If anything in the 400 or 500 range, error.
	print("Probing external link", url)
	try:
		r = requests.get(url, allow_redirects=False)
	except requests.exceptions.ConnectionError:
		print("** Unreadable external link **")
		config["known_links"][url] = False
		return
	config["known_links"][url] = r.ok
	parsed = urllib.parse.urlparse(url)
	if parsed.scheme == "http":
		dest = r.headers["Location"] if r.is_redirect else None
		# If it sends us to the exact same URL but with https://,
		# make it an autoredirect for the entire domain. This assumes
		# that no server will ever redirect http://x.y.example/path1 to
		# https://x.y.example/path1 without also supporting https for
		# every other possible URL at that domain.
		# However, if it redirects us elsewhere, or doesn't redirect at
		# all, record that we do not flip to HTTPS on this domain.
		config["use_https"][parsed.netloc] = use = dest == parsed._replace(scheme="https").geturl()
		print("HTTP->HTTPS redirect", "activated" if use else "rejected")
		if use: return # No point recording a specific redirect if it's a general one
	if r.is_permanent_redirect:
		print("Remembering redirect to", r.headers["Location"])
		config["redirects"][url] = r.headers["Location"]
		return
	if not r.ok:
		print("** Broken external link **")
		print(r)

@handler("AUTOFIX")
def autofix(type, context, url, extra):
	# Some errors can be fixed automatically.
	# Go through the file, find all references to 'url', replace with extra[0].
	print("FIX", context, url, extra[0])
	if context.endswith("/"): return
	root = "/home/rosuav/gsarchive/live"
	mangled = root + "/backups/" + context.replace("/", "_")
	if not os.path.exists(mangled): os.rename(root + context, mangled)
	from bs4 import BeautifulSoup
	with open(mangled, "rb") as f:
		soup = BeautifulSoup(f.read(), "html.parser")
	for attr in "src", "href", "background":
		for elem in soup.find_all(attrs={attr: url}):
			elem[attr] = extra[0]
	with open(root + context, "wb") as f:
		# Note: Using the HTML5 formatter with HTML4 Transitional documents (as many
		# of these files are) may cause oddities. Ultimately, we should just move to
		# all HTML5 files anyway, at which point it won't matter; in the meantime,
		# there may be some quirks with odd attributes. This is why we have backups.
		# (Anyway, the files seem to use HTML5 style booleans already, so it's not
		# going to be any worse.)
		f.write(soup.encode(formatter="html5"))

@handler("Internal link not found")
def intlink(type, context, url, extra):
	# Some broken internal links follow known patterns
	# Add rules here that will turn these into autofixables
	pass

try:
	with open("weakest_link.log") as log:
		for line in log:
			if not line: continue
			type, context, url, *extra = json.loads(line)
			if type in handlers: handlers[type](type, context, url, extra)
except KeyboardInterrupt: pass # Halting should be safe any time
finally:
	# Always save the configs, even if we bomb with an error
	with open("weakest_link.json", "w") as f:
		json.dump(config, f, indent=4, sort_keys=True)
