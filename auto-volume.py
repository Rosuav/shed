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
	if fn.lower().endswith(".mid") or fn.lower().endswith(".kar") or fn.lower().endswith(".xml"):
		# These files are almost certainly going to be unparseable. Save ourselves the trouble.
		return

	try:
		audio = pydub.AudioSegment.from_file(fn)
		print("%s: %.2f dB (max %.2f)" % (fn, audio.dBFS, audio.max_dBFS))
		# Find leading/trailing silence by iteratively scanning the start/end
		# until we find some actual audio. Total silence shows up as -inf, but
		# teeny bits of sound might show up with extremely negative values.
		# Tweak the threshold of -100 until it's satisfactory.
		for head in range(10, len(audio), 10):
			if audio[:head].dBFS > -100: break
		for tail in range(10, len(audio), 10):
			if audio[-tail:].dBFS > -100: break
		head = max(head - 250, 0) # Skip all but a quarter-second of silence
		tail = max(tail - 250, 0)
		file_info[fn] = {"vol": audio.dBFS, "lead": head, "trail": tail}
		file_info[...] = True
	except pydub.exceptions.CouldntDecodeError:
		print(fn, "... unable to parse")
	except KeyError:
		# There's some sort of problem with parsing some webm files.
		# Can be fixed by using FFMPEG to change container format to MKV
		# (use "-c copy" to avoid transcoding the actual data). For now,
		# just skip these files (they'll be re-attempted next time).
		# It seems to be an issue with files containing vp9 video?? Not
		# always webm containers. Maybe pydub is querying a list of
		# tracks, finding that [0] is video and [1] is audio, but then
		# is getting back only the audio track, because the video is
		# unparseable??? Debug this later. For now, just move on.
		print(fn, "... KeyError parse failure")
	except:
		# If anything else goes wrong, show which file failed.
		print(fn)
		raise

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
			data = template.read()
			# Patch in volume data
			before, after = data.split("-- [ volume-data-goes-here ] --", 1)
			vol = [ "[%r]=%s," % ("file://" + fn, file_info[fn]["vol"] * 2.56)
				for fn in sorted(file_info) ]
			data = before + "\n\t".join(vol) + after
			# Patch in lead silence data
			before, after = data.split("-- [ start-silence-data-goes-here ] --", 1)
			sil = [ "[%r]=%s," % ("file://" + fn, file_info[fn]["lead"] * 1000)
				for fn in sorted(file_info) if file_info[fn].get("lead")]
			data = before + "\n\t".join(sil) + after
			# Patch in trail silence data
			before, after = data.split("-- [ end-silence-data-goes-here ] --", 1)
			sil = [ "[%r]=%s," % ("file://" + fn, file_info[fn]["trail"] * 1000)
				for fn in sorted(file_info) if file_info[fn].get("trail")]
			data = before + "\n\t".join(sil) + after
			out.write(data)
	if args.play:
		os.execvp("vlc", ["vlc"] + args.paths)
