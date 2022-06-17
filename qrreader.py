# Read QR codes off the screen and display them
# Can optionally dump them into Twitch chat
import codecs
import re
import time
from PIL import ImageGrab, ImageFilter # ImportError? pip install pillow
from pyzbar.pyzbar import decode # ImportError? pip install pyzbar (maybe apt install libzbar-dev)
import clize # ImportError? pip install clize
try: from requests import post as requests_post
except ImportError: requests_post = lambda *a,**kw: None

def boundingbox(monitor):
	import subprocess, re
	p = subprocess.run(["xrandr", "--listactivemonitors"], capture_output=True, text=True, check=True)
	for line in p.stdout.split("\n")[1:]: # First line just gives the count
		idx, name, pos, id = line.split()
		if monitor == "primary" and "*" not in name: continue
		if monitor != "primary" and id != monitor: continue # Option 3: Specify by connection
		# eg 1920/531x1080/299+1920+0
		width, _, height, _, left, top = map(int, re.split("[^0-9]+", pos))
		return (left, top, left+width, top+height) # Bounding box wants right and bottom, not width and height
	return None # Or should it error out?

@clize.run
def main(*, interval=0.5, monitor="primary", ocr=0, twitch=False):
	"""Monitor the screen for QR codes and list them
	
	interval: Seconds between screen grabs. If 0, does one grab and then stops.

	monitor: Which monitor to monitor. If "all", captures all connected monitors.
	If "primary", captures the primary monitor. Otherwise, use an ID like "DP-3".

	ocr: If nonzero, every Nth frame will be OCR'd.

	twitch: Enable automatic posting of seen messages to Twitch (via StilleBot).
	"""
	if monitor == "all": bbox = None
	else: bbox = boundingbox(monitor)
	seen = { }
	ocr_count = 0
	if ocr:
		import pytesseract # ImportError? pip install pytesseract, and install the underlying app
	def got_message(msg, label):
		if msg not in seen:
			seen[msg] = 1
			print(msg)
			# If possible, poke a message through to StilleBot. Will fail if not on localhost.
			if twitch: requests_post("https://sikorsky.rosuav.com/admin", json={
				"cmd": "send_message",
				"channel": "#rosuav",
				"msg": label + " MrDestructoid brollC2 " + msg.replace("\n", " ") + " brollC2 MrDestructoid",
			})
	while True:
		img = ImageGrab.grab(bbox=bbox)
		for result in decode(img):
			if result.type != "QRCODE": continue # Ignore false positives that happen to look like barcodes
			msg = result.data.decode()
			got_message(msg, "QR code decoded!")
		ocr_count += 1
		if ocr_count == ocr:
			ocr_count = 0
			text = pytesseract.image_to_string(img.filter(ImageFilter.BoxBlur(1)).convert("L", colors=2))
			# Scan the text for hex strings - a minimum of three bytes. Interior nonsense
			# is permitted, but we strip it out before decoding.
			found_hex = ""
			for txt in re.findall("[A-F0-9 !@#$%^&*/_]{6,}", text.replace("\n", " ")):
				hex = re.sub("[^A-F0-9]+", "", txt)
				if len(hex) < 6: continue # Not enough hex digits.
				# Since we're expecting ASCII representations of text, the first
				# digits will frequently be 4, 5, 6, or 7. The second digits will
				# be more evenly distributed. If it looks like the second digits
				# are mostly 4567, then we might be desynchronized. (Note that we
				# won't try to resync in the middle of a string.)
				firsts, seconds = [sum('4' <= c <= '7' for c in hex[n::2]) for n in range(2)]
				if len(hex) % 2:
					# Odd length. Whichever end seems more likely, go with it;
					# we have to pad one end or the other anyway.
					if firsts > seconds: hex += "0"
					else: hex = "0" + hex
				else:
					# Even length. If there's a 2:1 ratio, adjust; otherwise,
					# we can use it as-is.
					if seconds >= firsts * 2: hex = "0" + hex + "0"
				try:
					text = ascii(codecs.decode(hex, "hex").decode("ascii"))[1:-1]
				except UnicodeDecodeError:
					continue # If there are any non-ASCII characters in there, it's clearly not interesting
				letters = sum('A' <= x <= 'Z' or 'a' <= x <= 'z' for x in text)
				if letters < 5: continue # Require five alphabetics to claim it as a word
				found_hex += " " + text
			if found_hex:
				# Send a signal through to StilleBot to update a variable
				requests_post("https://sikorsky.rosuav.com/admin", json={
					"cmd": "send_message",
					"channel": "#rosuav",
					"msg": {"dest": "/set", "target": "hextext", "message": found_hex.replace("\n", " ")},
				})
		if interval <= 0: break
		time.sleep(interval)
