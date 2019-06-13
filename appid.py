# Find a Steam appid given its name
import json
import os.path
import sys
from fuzzywuzzy import process # ImportError? pip install 'fuzzywuzzy[speedup]'

CACHE_FILE = os.path.abspath(__file__ + "/../appid.json")

try:
	with open(CACHE_FILE) as f:
		appids = json.load(f)
except FileNotFoundError:
	import requests # ImportError? pip install requests
	print("Downloading Steam appid list...")
	r = requests.get("https://api.steampowered.com/ISteamApps/GetAppList/v0001/")
	r.raise_for_status()
	data = r.json()
	appids = {app["name"]: app["appid"] for app in data["applist"]["apps"]["app"]}
	with open(CACHE_FILE, "w") as f:
		json.dump(appids, f)
	print("Downloaded and cached.")

if len(sys.argv) == 1:
	print("TODO: Use os.getcwd()")
	sys.exit(0)

for arg in sys.argv[1:]:
	...
