# Find a Steam appid given its name
import json
import sys
from fuzzywuzzy import process # ImportError? pip install 'fuzzywuzzy[speedup]'

try:
	with open("appid.json") as f:
		data = json.load(f)
except FileNotFoundError:
	import requests # ImportError? pip install requests
	print("Downloading Steam appid list...")
	r = requests.get("https://api.steampowered.com/ISteamApps/GetAppList/v0001/")
	r.raise_for_status()
	data = r.json()
	with open("appid.json", "w") as f:
		json.dump(data, f)
	print("Downloaded and cached.")

if len(sys.argv) == 1:
	print("TODO: Use os.getcwd()")
	sys.exit(0)

for arg in sys.argv[1:]:
	...
