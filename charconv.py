#!/usr/local/bin/python3
import sys
if len(sys.argv)==2:
	# Probe with all the ISO-8859-* modes, show the beginning of the file
	# in each one.
	with open(sys.argv[1], "rb") as f: data=f.read(1024)
	# Assuming an ASCII-compatible encoding, take the first paragraph.
	data = data.replace(b"\r",b"").split(b"\n\n")[0]
	encodings = [None,
		"Western European", "Central European", "South European", "North European", "Cyrillic",
		"Arabic", "Greek", "Hebrew", "Turkish", "Nordic", "Thai", "(Devanagari)", "Baltic Rim",
		"Celtic", "Latin-9", "South-Eastern European"
	]
	for enc, name in enumerate(encodings):
		try: print("ISO-8859-%d - %s:\n%s\n"%(enc,name,data.decode("iso-8859-"+str(enc))))
		except UnicodeDecodeError: pass # A thrown error means it's almost certainly not that encoding, so don't display it
		except LookupError: pass # ISO-8859-0 doesn't exist, but it's simpler to have a shim. Also, ISO-8859-12 was dropped.
	# On the off-chance that it's actually UTF-8, display that.
	# Placed last, it'll be highly obvious at the console.
	try: print("UTF-8:\n%s"%data.decode("utf-8"))
	except UnicodeDecodeError: pass
	sys.exit()
me, srt, enc1, enc2 = sys.argv
with open(srt, encoding=enc1) as f: data=f.read()
with open(srt, "w", encoding=enc2) as f: f.write(data)
