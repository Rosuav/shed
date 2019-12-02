# Build auto-volume.lua from the template and a JSON file of data
import os
import re
import json
import argparse
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse
import pydub

# Expects a series of paths as arguments. Files will be checked;
# directories will be recursed into. Unreadable or unparseable files
# will be ignored.

CACHE_FILE = os.path.abspath(os.path.join(__file__, "../auto-volume.json"))
TEMPLATE_FILE = os.path.abspath(os.path.join(__file__, "../auto-volume.lua"))
file_info = {}

def parse_file(fn, *, force=False):
	fn = os.path.abspath(fn)
	if fn in file_info and not force: return
	# TODO: Detect playlists more reliably (and handle m3u too)
	if fn.endswith(".xspf"):
		for el in ET.parse(fn).getroot().findall(".//*/{http://xspf.org/ns/0/}location"):
			parse_file(unquote(urlparse(el.text).path), force=force)
		return

	try:
		audio = pydub.AudioSegment.from_file(fn)
		print("%s: %.2f dB (max %.2f)" % (fn, audio.dBFS, audio.max_dBFS))
		file_info[fn] = {"vol": audio.dBFS}
		file_info[...] = True
		# TODO: Also figure out if there's leading silence
	except pydub.exceptions.CouldntDecodeError:
		print(fn, "... unable to parse")

# CAUTION: This will recurse into symlinked directories. Don't symlink back to the
# parent or you'll get a lovely little infinite loop.
def parse_dir(path, *, force=False):
	for child in os.scandir(path):
		if child.is_dir(): parse_dir(child.path, force=force)
		else: parse_file(child.path, force=force)

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description="VLC Auto-Volume pre-parser")
	parser.add_argument("-a", "--all", help="Parse all files even if we've seen them already", action="store_true")
	parser.add_argument("--play", help="Invoke VLC after parsing", action="store_true")
	parser.add_argument("paths", metavar="file", nargs='+', help="File/dir to process")
	args = parser.parse_args()
	try:
		with open(CACHE_FILE) as f: file_info = json.load(f)
	except FileNotFoundError: pass
	for path in args.paths:
		if os.path.isdir(path): parse_dir(path, force=args.all)
		else: parse_file(path, force=args.all)
	if ... in file_info: # Dirty flag
		del file_info[...] # Remove the flag from the cache file
		with open(CACHE_FILE, "w") as f:
			json.dump(file_info, f)
		with open(os.path.expanduser("~/.local/share/vlc/lua/extensions/auto-volume.lua"), "w") as out, \
				open(TEMPLATE_FILE) as template:
			before, after = template.read().split("-- [ data-goes-here ] --", 1)
			data = [ "[%r]=%s," % ("file://" + fn, file_info[fn]["vol"] * 2.56)
				for fn in sorted(file_info) ]
			out.write(before + "\n\t".join(data) + after)
	if args.play:
		os.execvp("vlc", args.paths)
