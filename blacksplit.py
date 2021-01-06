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

# After this are all the chapter definitions.

# Write a single chapter to this file
OUTPUT=1,chapter1.mkv
# Skip one chapter
OUTPUT=1,--
# There's a black moment inside this logical chapter, so write out two
# consecutive chapters as a single file.
OUTPUT=2,chapter2.mkv
# Etc. If blacksplit.py is run with the --append parameter, it will
# add null entries to this file, annotated with timing marker comments,
# and specifying no output; all you have to do is edit the file names
# (and possibly merge some if necessary).
"""

# Abuse of __doc__ :)
class BadScriptFile(Exception): "Unknown error (shouldn't happen)" 
class UnknownDirective(BadScriptFile): "Unrecognized directive %r on line %d"
class MissingInput(BadScriptFile): "No INPUT=filename found"
# TODO: Bad OUTPUT directive

def black_split(script, append_unknowns):
	cfg = {
		"INPUT": None, # Must be specified
		"pixel_black_th": "0.10", # Same defaults as ffmpeg uses
		"picture_black_ratio_th": "0.98",
		"black_min_duration": "2.0",
	}
	outputs = []

	with open(script) as f:
		for pos, line in enumerate(f, 1):
			line = line.split("#")[0].strip() # yeah it's naive, no quoting of hashes
			if not line: continue
			if "=" in line:
				key, val = line.split("=", 1)
				if key in cfg: cfg[key] = val
				elif key == "OUTPUT": outputs.append(val)
				else: raise UnknownDirective(line, pos)
	if cfg["INPUT"] is None: raise MissingInput
	print(cfg)
	print(outputs)
	# ffprobe -f lavfi -i "movie="+fn+",blackdetect=d=0.25:pix_th=0.1[out0]" -show_entries tags=lavfi.black_start,lavfi.black_end -of default=nw=1 -v quiet

if __name__ == "__main__":
	import sys
	append = "--append" in sys.argv
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	if "--help" in sys.argv or not args:
		print("USAGE: python3 %s scriptfile" % sys.argv[0])
		print("For scriptfile format, see docstring")
		sys.exit(0)
	for fn in args:
		try:
			black_split(fn, append)
		except BadScriptFile as e:
			print(e.__doc__ % e.args)
			break
