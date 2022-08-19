# Broken link finder/fixer
# 1. Starting with a given page, scan for all references
#    <* href="..."> mainly <a> but also <link>
#    <* src="..."> eg img, script, style
#    <* background="..."> for inline background image styles?
# 2. If ref is external (http:// or https:// and not gsarchive.net), record
#    the domain name in case there's a different sort of error. A separate
#    pass to validate external links will be of value, but should be cached
#    aggressively.
# 3. If ref is unnecessarily-external (pointing to gsarchive.net), autofix
#    to relative.
# 4. If ref is internal and the file exists, queue the target for scanning,
#    if not already queued or scanned.
# 5. If ref is internal and not found:
#    a. <nothing here yet - cf "is it an elephant">
#    b. Log the failure
# 6. Progressively go through the log and add autofixers
# 7. Enumerate all files in the directory. If any file is not probed, list
#    it. This will give a good indication of missing link detection (eg CSS
#    references to images), and a list of potential destinations for broken
#    links, which can be fuzzy-matched to suggest possible solutions.
import json
import os
from urllib.parse import urlparse, urljoin, ParseResult
from bs4 import BeautifulSoup
root = "/home/rosuav/gsarchive/live"

scanned = { }
awaiting = []
logged = { }
config = { }
try:
	with open("weakest_link.json") as f: config = json.load(f)
except FileNotFoundError: pass
for ensure in "redirects", "use_https", "known_links": # Match weakest_link_checker
	if ensure not in config: config[ensure] = { }

logfile = open("weakest_link.log", "w")
def report(*msg):
	print(json.dumps(msg), file=logfile)
	print(*msg)

def report_once(key, *msg):
	if key in logged: return
	logged[key] = 1
	report(*msg)

def fix(oldurl, newurl, context):
	report("AUTOFIX", context, oldurl, newurl)

def path_from_fn(fn):
	path = root + fn
	if path.endswith("/"):
		# Directory names get handled by index files
		path += "index.html" # Is this the only name available? If multiple, what priority order?
	return path

def link(context, url, *, base="https://gsarchive.net/"):
	# Make the URL absolute
	uri = urljoin(urljoin(base, context), url)
	fn = None
	match urlparse(uri):
		case ParseResult(scheme="http", netloc="gsarchive.net"):
			report("Non-encrypted link within site", context, url)
		case ParseResult(scheme="http") as p:
			# Attempt to autoflip to HTTPS if possible (if we don't know, probe that);
			# otherwise, it's an external link like any other.
			match config["use_https"].get(p.netloc):
				case None:
					report_once("http-" + p.netloc, "Non-encrypted link outside site", context, url)
				case True:
					fix(url, p._replace(scheme="https").geturl(), context)
				case False:
					report_once("http-" + p.netloc, "External link", context, url)
				case _:
					report("BROKEN STATE", context, url)
		case ParseResult(scheme="https", netloc="www.gsarchive.net") as p:
			# Links to www.gsarchive.net should definitely become relative
			fix(url, p.path, context)
			fn = p.path
		case ParseResult(scheme="https", netloc="gsarchive.net") as p:
			if url.startswith("https:"):
				# The URL was stored absolute, which is inefficient and vulnerable to error
				fix(url, p.path, context)
			fn = p.path
		case ParseResult(scheme="https") as p:
			report_once("https-" + p.netloc, "External link", context, url)
		case ParseResult(scheme="mailto") as p:
			report_once("mailto-" + p.path, "Email link", context, url)
		case ParseResult():
			report("Non-HTTP link", context, url)
		case _:
			report("Unparseable link", context, url)
	if not fn: return
	if fn in scanned: return
	scanned[fn] = 1
	if not os.path.exists(path_from_fn(fn)):
		report("Internal link not found", context, url, fn)
		return
	base, dot, ext = fn.rpartition(".")
	if not dot or ext in ("html", "htm"):
		awaiting.append(fn)
	# Anything else we should be checking? Scan CSS files for references, maybe?

def find_links(fn):
	with open(path_from_fn(fn), "rb") as f:
		soup = BeautifulSoup(f.read(), "html.parser")
	for attr in "src", "href", "background":
		for elem in soup.find_all(attrs={attr: True}):
			link(fn, elem.get(attr))

link("/", "/")
while awaiting:
	fn = awaiting.pop()
	print(fn, "...")
	find_links(fn)
