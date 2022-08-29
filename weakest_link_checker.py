# Read the log created by weakest_link.py and enhance the configs
import json
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
