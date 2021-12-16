# Read QR codes off the screen and display them
# Can optionally dump them into Twitch chat
import time
from PIL import ImageGrab # ImportError? pip install pillow
from pyzbar.pyzbar import decode # ImportError? pip install pyzbar (maybe apt install libzbar-dev)
import clize # ImportError? pip install clize

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
def main(*, interval=0.5, monitor="primary"):
	"""Monitor the screen for QR codes and list them
	
	interval: Seconds between screen grabs. If 0, does one grab and then stops.

	monitor: Which monitor to monitor. If "all", captures all connected monitors.
	If "primary", captures the primary monitor. Otherwise, use an ID like "DP-3".
	"""
	if monitor == "all": bbox = None
	else: bbox = boundingbox(monitor)
	seen = { }
	while True:
		img = ImageGrab.grab(bbox=bbox)
		for result in decode(img):
			msg = result.data.decode()
			if msg in seen: continue
			seen[msg] = 1
			print(msg)
		if interval <= 0: break
		time.sleep(interval)
