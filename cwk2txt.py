#!/usr/bin/env python3
import sys
if len(sys.argv) < 2:
	print("USAGE: %s filename.cwk" % sys.argv[0])
	print("Will create filename.txt")
	sys.exit(1)

infn = sys.argv[1]
outfn = infn[:-3] + "txt"
markers = [b"Waverley Historical Society Inc\r", b"Minutes of Committee Meeting"]

with open(infn, "rb") as f: data = f.read()
parts = []
for marker in markers:
	parts = data.split(marker, 1)
	if len(parts) == 2: break # leaving 'marker' set appropriately
if len(parts) < 2:
	print("File lacks any known marker, which currently are:")
	print(repr(markers))
	print("Manual work will be needed, sorry!")
	sys.exit(0)

with open(outfn, "wt", encoding="utf-8") as f:
	# The data is actually chunked. The two bytes at the end of parts[0]
	# are the length of the first chunk, which is followed by \0\0 and the
	# next chunk's length.
	data = marker + parts[1]
	chunklen = parts[0][-2] << 8 | parts[0][-1]
	body = b""
	while chunklen:
		body += data[:chunklen]; data = data[chunklen:]
		# Go till we find a \0 termination marker
		if body[-1] == 0: break
		print(repr(data[:80]))
		assert data[:2] == b"\0\0"
		chunklen = data[2] << 8 | data[3]
		data = data[4:]

	text = body.rstrip(b"\0").decode("MacRoman")
	text = text.replace("\r", "\n")
	f.write(text)
