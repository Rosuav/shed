import asyncio
import re
import pydub

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

async def send_status(writer):
	while not writer.is_closing():
		writer.write(b"status\n")
		await writer.drain()
		await asyncio.sleep(30)

async def tcp_echo_client():
	reader, writer = await asyncio.open_connection("127.0.0.1", 4212)
	writer.write(b"password-goes-here\n") # Substitute your VLC telnet password
	await writer.drain()
	asyncio.ensure_future(send_status(writer))
	fn = None
	async for line in read_telnet_lines(reader):
		m = re.search(r"\( new input: file://(.+) \)$", line)
		if not m: continue
		if m[1] == fn: continue # Same file as before
		fn = m[1]
		print(fn, "... parsing...", end="\r")
		try:
			audio = pydub.AudioSegment.from_file(fn)
			print("%s: %.2f dB (max %.2f)" % (fn, audio.dBFS, audio.max_dBFS))
		except pydub.exceptions.CouldntDecodeError:
			print(fn, "... unable to parse")

asyncio.run(tcp_echo_client())
