import asyncio
import os
import re
import pydub
from urllib.parse import unquote

async def read_telnet_lines(reader):
	"""Generate lines of telnet-stripped data

	Like repeatedly awaiting reader.readline(), but strips TELNET
	codes first. Since a TELNET sequence could include b"\n", the
	processing cannot be done line-by-line.
	"""
	telnetbuffer = textbuffer = b""
	while True:
		data = await reader.read(256)
		if not data: break
		data = telnetbuffer + data
		telnetbuffer = b""
		while b"\xFF" in data:
			txt, iac = data.split(b"\xFF", 1)
			textbuffer += txt
			if iac == b"":
				# IAC at the very end of the data? Incomplete TELNET
				# sequence. Wait for more text.
				telnetbuffer = b"\xFF"
				data = b""
				break
			if iac[0] in b"\xF0\xF1\xF9\xFA":
				# IAC GA, IAC NOP - ignore them
				# IAC SB ... IAC SE - can't be bothered
				data = iac[1:]
				continue
			if iac[0] in b"\xFB\xFC\xFD\xFE":
				# IAC DO/DONT/WILL/WONT
				if len(iac) > 1:
					data = iac[2:]
					continue
				# Else we have an incomplete sequence.
				telnetbuffer = b"\xFF" + iac
				data = b""
				break
			raise ValueError("Unexpected bytes following IAC: %r" % iac[:16]) # Shouldn't happen? Probably?
		textbuffer += data
		# Okay, we have some text. Find any lines and yield them,
		# then go back for more text.
		*lines, textbuffer = textbuffer.split(b"\n")
		for line in lines:
			yield line.strip(b"\r").decode("utf-8")

async def client(reader, writer):
	print("Received connection from %s:%s" % writer.transport.get_extra_info("peername")[:2])
	await writer.drain()
	async for line in read_telnet_lines(reader):
		if line == "quit": break
		if not line.startswith("file://"): continue
		fn = unquote(line[7:])
		print(fn, "... parsing...", end="\n")
		try:
			audio = pydub.AudioSegment.from_file(fn)
		except (pydub.exceptions.CouldntDecodeError, FileNotFoundError, IndexError):
			# IndexError seems to happen with video-only files
			print(fn, "... unable to parse")
			writer.write(b"%s: n/a\n" % line.encode("utf-8"))
			await writer.drain()
			continue
		print("%s: %.2f dB (max %.2f)" % (fn, audio.dBFS, audio.max_dBFS))
		writer.write(b"%s: %.2f\n" % (line.encode("utf-8"), audio.dBFS))
		await writer.drain()
	writer.close()
	print("Disconnected.")

async def listen():
	mainsock = await asyncio.start_server(client, port=4321)
	print("Listening:", ", ".join("%s:%s" % s.getsockname()[:2] for s in mainsock.sockets))
	await mainsock.serve_forever()

asyncio.run(listen())
