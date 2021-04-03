"""
Split a video file into chapters by detecting fade/cut to black

Script file should look like this. Note that as long as the INPUT
directive is found, everything else can be ignored.

# Path to input file (note that comments are ignored)
INPUT=/path/to/inputfile.mkv
# Optional blackness threshold (a pixel is black if darker than this)
# pixel_black_th=0.10
# Optional picture blackness threshold (a frame is black if this many
# of its pixels are considered black)
# picture_black_ratio_th=0.98
# Optional blackness duration to define a segment. Once we have this much
# blackness, we count a new segment. The default (2.0) is usually too long.
black_min_duration=0.25
# Rather than reprobe the file repeatedly, save the ffprobe result to a file.
# If any of the blackdetect parameters change, the cache will be discarded.
# Note that the cache file can store data from multiple input files and/or
# multiple blackness detection schemes independently.
cache_file=some_file.json
# Create output file names with a pattern for convenience. Use {n} for the
# file name (numbered from 1 with the first output that isn't "--"), and
# the description given on the output line is {desc}.
# output_format={n:02d} - {desc}
# Numbering for the output file names starts at this index:
# first_track=1

# After this are all the chapter definitions.

# Write a single chapter to this file
OUTPUT=1,chapter1.mkv
# Skip one chapter
OUTPUT=1,--
# There's a black moment inside this logical chapter, so write out two
# consecutive chapters as a single file.
OUTPUT=2,chapter2.mkv; trimstart=2; trimend=4
# Etc. If blacksplit.py is run with the --append parameter, it will
# add null entries to this file, annotated with timing marker comments,
# and specifying no output; all you have to do is edit the file names
# (and possibly merge some if necessary).
# If the black detection isn't perfect, adjust it with a trim marker
# (number of seconds, start and/or end). These values may be negative.
"""
import json
import os
import subprocess

# TODO: Diffing mode
# Take the existing settings as the baseline, and diff the black detection against
# something specified on the command line. For instance: "--diff pixel_black_th=0.08"
# to see what it'd be like with a different per-pixel threshold. Use the cache for
# both sides if possible. Do a diffing of the info that goes into the comment lines:
# "Chapter N: from 28:52.770 to 28:55.650 ==> 2.880" - ignore the chapter numbers,
# and just compare the timestamps. A naive diff should be sufficient here.

# Abuse of __doc__ :)
class BadScriptFile(Exception): "Unknown error (shouldn't happen)" 
class UnknownDirective(BadScriptFile): "Unrecognized directive %r on line %d"
class MissingInput(BadScriptFile): "No INPUT=filename found"
class BadInput(BadScriptFile): "Input file not found - %r on line %d"
class BadOutput(BadScriptFile): "Invalid OUTPUT directive %r on line %d"

def human_time(s):
	"""Convert floating-point seconds into human-readable time"""
	if s < 60.0: return "%.3f" % s
	m = int(s) / 60
	if m < 60: return "%d:%06.3f" % (m, s % 60)
	return "%d:%02d:%06.3f" % (m // 60, m % 60, s % 60)

def black_split(script, *, append=False, createonly=False):
	cfg = {
		"pixel_black_th": "0.10", # Same defaults as ffmpeg uses
		"picture_black_ratio_th": "0.98",
		"black_min_duration": "2.0",
		"cache_file": None,
		"first_track": "1",
		"output_format": "{n:02d} - {desc}",
	}
	inputs, outputs = [], []

	with open(script) as f:
		for pos, line in enumerate(f, 1):
			line = line.split("#")[0].strip() # yeah it's naive, no quoting of hashes
			if not line: continue
			if "=" in line:
				key, val = line.split("=", 1)
				if key in cfg: cfg[key] = val
				elif key == "INPUT":
					try: os.stat(val)
					except FileNotFoundError: raise BadInput(val, pos) from None
					inputs.append(val)
				elif key == "OUTPUT":
					if "," not in val: raise BadOutput(line, pos)
					count, fn = val.split(",", 1)
					try: count = int(count)
					except ValueError: raise BadOutput(line, pos)
					if count < 1: raise BadOutput(line, pos)
					# If count is 3, add two Ellipsis entries and then the file name
					outputs.extend([...] * (count - 1))
					outputs.append(fn)
				else: raise UnknownDirective(line, pos)
	if not inputs: raise MissingInput
	min_black = float(cfg["black_min_duration"]) # ValueError if bad duration format
	bdparams = ":".join(f"{k}={cfg[k]}" for k in "pixel_black_th picture_black_ratio_th black_min_duration".split())
	cache = { }
	if cfg["cache_file"]:
		try:
			with open(cfg["cache_file"]) as f:
				cache = json.load(f)
			if not isinstance(cache, dict): cache = { }
		except FileNotFoundError:
			pass
	file_no = int(cfg["first_track"])
	output_idx = 0
	for inputfile in inputs:
		cache_key = "%r-%r" % (inputfile, bdparams)
		if cache_key not in cache:
			print("Finding blackness...") # Hello, blackness, my old... friend??
			with subprocess.Popen([
				"ffprobe", "-f", "lavfi",
				"-i", f"movie={inputfile},blackdetect={bdparams}[out0]",
				"-show_entries", "tags=lavfi.black_start,lavfi.black_end",
				"-of", "default=nw=1", "-hide_banner",
			], stdout=subprocess.PIPE, text=True) as proc:
				cache[cache_key] = []
				for line in proc.stdout:
					# TODO: Provide some sort of progress indication?
					# It'd be jerky (emitting only when a blackness is
					# found), but better than nothing.
					cache[cache_key].append(line.rstrip("\n"))
			if cfg["cache_file"]:
				with open(cfg["cache_file"], "w") as f:
					json.dump(cache, f, sort_keys=True, indent=4)
				print("Saved to cache for next time.")
		last_start = last_end = None
		last_end = 0.0
		append_desc = "\n# %s:\n" % inputfile
		for line in cache[cache_key]:
			if "=" not in line: continue
			key, val = line.split("=", 1)
			# NOTE: The lines sometimes appear to be duplicated. Don't get thrown off by this.
			if key == "TAG:lavfi.black_start": last_start = float(val)
			if key == "TAG:lavfi.black_end" and last_start is not None:
				start, end, last_start = last_start, float(val), None
				if end - start < min_black: continue
				output_idx += 1 # Using 1-based indexing for human convenience
				# NOTE: The "start" and "end" are of the blackness. A chapter runs from
				# last_end to start, spanning the time of non-blackness between the black.
				if output_idx > len(outputs):
					fr, to, dur = human_time(last_end), human_time(start), human_time(start - last_end)
					if append:
						with open(script, "a") as f:
							print("%s# Chapter %d: from %s to %s ==> %s" %
								(append_desc, output_idx, fr, to, dur), file=f)
							print("OUTPUT=1,--", file=f)
							append_desc = ""
					print("New chapter: from %s to %s, %s" % (fr, to, dur))
					last_end = end
					continue
				output = outputs[output_idx - 1]
				if output is ...:
					# Continue this into the next one.
					# That's actually quite simple; we just don't change last_end,
					# meaning that the start of the next block will include this.
					continue
				if output != "--": # An output of "--" means no file to create
					output, *args = output.split("; ")
					args = dict(arg.split("=", 1) for arg in args)
					output = cfg["output_format"].format(n=file_no, desc=output)
					file_no += 1
					if createonly and os.path.exists(output):
						print("Skipping:", output)
						last_end = end
						continue
					print("Creating:", output)
					skipstart = int(args.get("trimstart", 0))
					skipend = skipstart + int(args.get("trimend", 0)) # Since humans want to think about trims, not lengths
					subprocess.run([
						"ffmpeg", "-i", inputfile,
						"-ss", str(last_end + skipstart),
						"-t", str(start - last_end - skipend),
						"-c", "copy", output,
						"-y", "-loglevel", "quiet", "-stats",
					], check=True)
				last_end = end
	print("To chain another file:")
	print("first_track=%d" % file_no)

if __name__ == "__main__":
	import sys
	flags = {flg.strip("-"): True for flg in sys.argv if flg.startswith("--")}
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	if "--help" in sys.argv or not args:
		print("USAGE: python3 %s scriptfile" % sys.argv[0])
		print("For scriptfile format, see docstring")
		sys.exit(0)
	for fn in args:
		try:
			black_split(fn, **flags)
		except BadScriptFile as e:
			print(e.__doc__ % e.args)
			break
