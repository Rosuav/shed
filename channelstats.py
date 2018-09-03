import requests
import urllib.parse

while True:
	mod = input("Enter the name of a mod to look up: ")
	if not mod: break
	r = requests.get("https://twitchstuff.3v.fi/modlookup/api/user/" + urllib.parse.quote(mod))
	r.raise_for_status()
	channels = [(c["views"] / c["followers"], c["views"], c["followers"], c["name"])
		for c in r.json()["channels"]]
	channels.sort(reverse=True)
	for channel in channels:
		print("%5.2f %7d %-6d %s" % channel)
