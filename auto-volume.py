# Build auto-volume.lua from the template and a JSON file of data
import os
import re
import shutil
import pydub

# Expects a series of paths as arguments. Files will be checked;
# directories will be recursed into. Unreadable or unparseable files
# will be ignored.

file_info = {}
# TODO: Read from auto-volume.json

def parse(fn):
	if fn is "directory":
		for fn in os.listdir(fn):
			parse(fn)
		return
	open(fn)
	# do stuff
	if 0:
		m = desired_volume is None and re.search(r"\( audio volume: ([0-9]+) \)$", line)
		if m:
			vol = int(m[1]) / 2.56 # Rescale from 0-255 to percentage
			assert last_dbfs is not None # This should come AFTER we find the filename
			desired_volume = vol + last_dbfs
			print("vol", vol, "desired", desired_volume)
		m = re.search(r"\( new input: file://(.+) \)$", line)
		if not m: continue
		if m[1] == fn: continue # Same file as before
		fn = m[1]
		print(abbrev(fn + " ... parsing..."), end="\r")
		try:
			audio = pydub.AudioSegment.from_file(fn)
			print("%s: %.2f dB (max %.2f)" % (fn, audio.dBFS, audio.max_dBFS))
			last_dbfs = audio.dBFS
			if desired_volume is not None:
				vol = desired_volume - audio.dBFS
				print("Setting volume to", vol)
				writer.write(b"volume %d\n" % int(vol * 2.56 + 0.5))
				await writer.drain()
		except pydub.exceptions.CouldntDecodeError:
			print(fn, "... unable to parse")

# TODO: argparse.
# --all -> process even if we already have data
# --play -> exec to VLC after processing
# and of course, filenames
