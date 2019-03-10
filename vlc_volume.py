import asyncio
import os
import re
import pydub

# Either change this line, or set the password in your environment
VLC_TELNET_PASSWORD = os.environ.get("VLC_TELNET_PASSWORD", "password-goes-here")
PASSWORD_COMMAND = VLC_TELNET_PASSWORD.encode("utf-8") + b"\n"

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
		writer.write(b"status\nget_time\nget_length\n")
		await writer.drain()
		await asyncio.sleep(30)

async def tcp_echo_client():
	reader, writer = await asyncio.open_connection("127.0.0.1", 4212)
	writer.write(PASSWORD_COMMAND)
	await writer.drain()
	asyncio.ensure_future(send_status(writer))
	next_number = fn = desired_volume = last_dbfs = None
	async for line in read_telnet_lines(reader):
		if line == "( state playing )":
			next_number = "time" # If we're paused, ignore all this
		elif next_number is not None and set(line) <= set("0123456789"):
			if next_number == "time":
				position = int(line)
				next_number = "length"
			else:
				length = int(line)
				next_number = None
				time_to_next_track = length - position + 1
				# If we're getting close to the next track, plan to check status
				# right after that track finishes. This will often give prompt
				# updates, and if that doesn't work, well, the periodic check
				# will catch it within 30 seconds.
				if time_to_next_track < 30:
					asyncio.get_event_loop().call_later(time_to_next_track,
						writer.write, b"status\nget_time\nget_length\n")
		else:
			next_number = None
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
		print(fn, "... parsing...", end="\r")
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

asyncio.run(tcp_echo_client())
