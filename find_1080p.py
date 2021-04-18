import subprocess, sys, json

for fn in sys.argv[1:]:
	info = json.loads(subprocess.check_output(["ffprobe", fn, "-print_format", "json", "-show_streams", "-v", "quiet"]))
	if "streams" not in info:
		print(fn + ": Unable to parse")
		continue
	for strm in info["streams"]:
		if strm["codec_type"] == "video" and strm["height"] >= 1000: break
	else: continue
	print("%s: %dx%d" % (fn, strm["width"], strm["height"]))
