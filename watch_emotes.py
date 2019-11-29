import sys
import time
import pprint
import subprocess
import requests
sys.path.append("../mustard-mine")
import config

emote_count = None
while emote_count is None or emote_count == len(emotes):
	req = requests.get("https://api.twitch.tv/kraken/chat/emoticon_images?emotesets=317117,317121,317122,1184925,1184926,1184927", headers={
		"Client-ID": config.CLIENT_ID,
		"Accept": "application/vnd.twitchtv.v5+json",
	})
	resp = req.json()
	emotes = {e["code"]: e["id"] for s in resp["emoticon_sets"].values() for e in s}
	# Optionally also watch for BTTV emotes
	#resp = requests.get("https://api.betterttv.net/2/channels/rosuav").json()
	#emotes.update({e["code"]: e["id"] for e in resp["emotes"]})
	pprint.pprint(emotes)
	# Whatever number there are on the first run, that's considered "current".
	# If it then changes, report it.
	if emote_count is None: emote_count = len(emotes)
	elif emote_count != len(emotes): break # Don't wait for the next minute
	time.sleep(60)
print("====================")
pprint.pprint(emotes)
subprocess.check_call(["vlc", "/video/Clips/Let It Go/Turkish - Aldirma.mkv"])
