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
import re
import collections
from urllib.parse import urlparse, urljoin, unquote, ParseResult
from bs4 import BeautifulSoup
root = "/home/rosuav/gsarchive/live"

scanned = { }
unscanned = set()
awaiting = []
logged = { }
config = { }
try:
	with open("weakest_link.json") as f: config = json.load(f)
except FileNotFoundError: pass
for ensure in "redirects", "use_https", "known_links": # Match weakest_link_checker
	if ensure not in config: config[ensure] = { }
try:
	# Build this file on the server for performance
	# find -type f|cut -c3-|grep -v '^backups/' >backups/all_files.txt
	with open(root + "/backups/all_files.txt") as f:
		unscanned = {"/" + line.strip() for line in f}
except FileNotFoundError: pass
unscanned_count = len(unscanned) # Progress is achieved by shrinking the set
# Links to these borked files are potentially a problem. Trace them.
borked = {
	"/html/perf_grps/websites/gb/index.html",
	"/carte/index.html",
	"/html/raywalker/faqs.html",
	"/html/shop_files/faqs.html",
}
files_by_content = collections.defaultdict(list)

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
	path = root + unquote(fn)
	if path.endswith("/"):
		# Directory names get handled by index files
		path += "index.html" # Is this the only name available? If multiple, what priority order?
	return path

def link(context, url, *, base="https://gsarchive.net/"):
	# Make the URL absolute
	uri = urljoin(urljoin(base, context), url)
	fn = None
	match urlparse(uri):
		case ParseResult(scheme="http", netloc="gsarchive.net") as p:
			fix(url, p.path, context)
			fn = p.path
		case ParseResult(scheme="http") as p:
			# Attempt to autoflip to HTTPS if possible (if we don't know, probe that);
			# otherwise, it's an external link like any other.
			match config["use_https"].get(p.netloc):
				case None:
					report_once("http-" + p.netloc, "Non-encrypted link outside site", context, url)
				case True:
					fix(url, p._replace(scheme="https").geturl(), context)
				case False:
					if p.netloc not in config["known_links"]:
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
			if p.netloc not in config["known_links"]:
				report_once("https-" + p.netloc, "External link", context, url)
		case ParseResult(scheme="mailto") as p:
			report_once("mailto-" + p.path, "Email link", context, url)
		case ParseResult(scheme="javascript") | ParseResult(scheme="JAVASCRIPT") as p:
			# Some JS links open files, which in a sense means they can be referenced.
			# TODO: Convert these so their hrefs point to the pages, and then have onclicks to open the popup
			# I don't feel like fetching up a full JavaScript lexer here, so I'm going to
			# assume that the majority of these follow a strict format, and any that don't
			# parse will get logged.
			m = re.match("openPop(Win|Img)\\(['\"]([^'\"]+)['\"],", p.path)
			if m: fn = urlparse(urljoin(urljoin(base, context), m[2])).path
			elif p.path == "popUp('sc3note.html')": fn = "/gilbert/plays/ruy_blas/sc3note.html" # Of course there's one that's different. Naturally.
			elif p.path == ";": pass # TODO: Get rid of unnecessary empty JS links?
			elif p.path == "window.close()": pass # TODO: Should these be done differently too?
			else: report("JavaScript link", context, url)
		case ParseResult(scheme="file") as p:
			report("Local file link", context, url)
		case ParseResult():
			report("Non-HTTP link", context, url)
		case _:
			report("Unparseable link", context, url)
	if not fn: return
	# There are a handful of borked files that I need to back-trace.
	if fn in borked: report("Link to borked file", context, url)
	if fn in scanned: return
	scanned[fn] = 1
	unscanned.discard(fn)
	if not os.path.exists(path_from_fn(fn)):
		report("Internal link not found", context, url, fn)
		return
	# Attempt to recognize duplicate files. Note that we could stat before
	# opening, but that's probably extra round trips. Haven't tested though.
	with open(path_from_fn(fn), "rb") as f:
		size = f.seek(0, 2)
		f.seek(0)
		if size <= 1048576:
			files_by_content[f.read()].append(fn)
	base, dot, ext = fn.rpartition(".")
	if not dot or ext in ("html", "htm"):
		awaiting.append(fn)
	# Anything else we should be checking? Scan CSS files for references, maybe?

def find_links(fn):
	with open(path_from_fn(fn), "rb") as f:
		soup = BeautifulSoup(f.read(), "html.parser")
	for attr in "src", "href", "background":
		for elem in soup.find_all(attrs={attr: True}):
			if elem.name == "a" and not elem.text and not list(elem.children):
				report("Empty anchor", fn, elem.get(attr))
			link(fn, elem.get(attr))

link("/", "/")
while awaiting:
	fn = awaiting.pop()
	print("[%d%% scanned, %d queued]" % (100 - len(unscanned) * 100 // unscanned_count, len(awaiting)), fn, "...")
	find_links(fn)

# Any unscanned files get logged.
for fn in sorted(unscanned):
	# See if they're duplicates of files that ARE referenced.
	with open(path_from_fn(fn), "rb") as f:
		size = f.seek(0, 2)
		f.seek(0)
		if size <= 1048576:
			files = files_by_content[f.read()]
			if len(files) == 1:
				report("Unscanned duplicate file", "/", fn, files[0])
				continue
			elif files:
				report("Unscanned replicant file", "/", fn, len(files))
				continue
	report("Unscanned file", "/", fn)

print(len(unscanned), "out of", unscanned_count, "still unscanned")
