# Build auto-volume.lua from the template and a JSON file of data
import os
import re
import argparse
import pydub

# Expects a series of paths as arguments. Files will be checked;
# directories will be recursed into. Unreadable or unparseable files
# will be ignored.

file_info = {}
# TODO: Read from auto-volume.json

def parse_file(fn, *, force=False):
	fn = os.path.abspath(fn)
	if fn in file_info and not force: return
	try:
		audio = pydub.AudioSegment.from_file(fn)
		print("%s: %.2f dB (max %.2f)" % (fn, audio.dBFS, audio.max_dBFS))
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
	for path in args.paths:
		if os.path.isdir(path): parse_dir(path, force=args.all)
		else: parse_file(path, force=args.all)
	if args.play:
		os.execvp("vlc", args.paths)
