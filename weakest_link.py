# Broken link finder/fixer
# 1. Starting with a given page, scan for all references
#    <* href="..."> mainly <a> but also <link>
#    <* src="..."> eg img, script, style
#    Anything else?
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
from urllib.parse import urlparse, urljoin, ParseResult
from bs4 import BeautifulSoup
root = "/home/rosuav/gsarchive/live"

scanned = { }
awaiting = []

def report(*msg):
	# TODO: Log to file?
	print(*msg)

def fix(oldurl, newurl, context):
	report("In", context, "replace", oldurl, "with", newurl)

def link(context, url, *, base="https://gsarchive.net/"):
	# Make the URL absolute
	uri = urljoin(base, url)
	fn = None
	match urlparse(uri):
		case ParseResult(scheme="http", netloc="gsarchive.net"):
			report("Non-encrypted link within site", context, url)
		case ParseResult(scheme="http"):
			report("Non-encrypted link outside site", context, url)
		case ParseResult(scheme="https", netloc="gsarchive.net") as p:
			if url.startswith("https:"):
				# The URL was stored absolute, which is inefficient and vulnerable to error
				fix(url, p.path)
			fn = p.path
		case ParseResult(scheme="https"):
			report("External link", context, url)
		case ParseResult():
			report("Non-HTTP link", context, url)
		case _:
			report("Unparseable link", context, url)
	if not fn: return
	if fn in scanned: return
	scanned[fn] = 1
	awaiting.append(fn)

def find_links(fn):
	path = root + fn
	if path.endswith("/"):
		# Directory names get handled by index files
		path += "index.html" # Is this the only name available? If multiple, what priority order?
	with open(path, "rb") as f:
		soup = BeautifulSoup(f.read(), "html.parser")
	print("Got soup")

link("", "/")
while awaiting:
	fn = awaiting.pop()
	print(fn, "...")
	find_links(fn)
