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
# Optional blackness duration to define a segment. Once we have this
# much blackness, we count a new segment. Default of 2.0 is too long.
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

def black_split(script, append_unknowns):
	...

if __name__ == "__main__":
	import sys
	append = "--append" in sys.argv
	args = [a for a in sys.argv[1:] if not a.startslike("--")]
	if "--help" in sys.argv or not args:
		print("USAGE: python3 %s scriptfile" % sys.argv[0])
		print("For scriptfile format, see docstring")
		sys.exit(0)
	for fn in args:
		black_split(fn, append)
