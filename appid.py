#!/usr/bin/env python3
# Find a Steam appid given its name
import json
import os.path
import sys
from fuzzywuzzy import process, fuzz # ImportError? pip install 'fuzzywuzzy[speedup]'

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

appnames = list(appids)
def shortest_token_set_ratio(query, choice):
	"""Like fuzz.token_set_ratio, but breaks ties by choosing the shortest"""
	return fuzz.token_set_ratio(query, choice) * 1000 + 1000 - len(choice)
def show_matches(target):
	for name, score in process.extract(target, appnames, limit=10, scorer=shortest_token_set_ratio):
		print("\t[%3d%% - %7s] %s" % (score//1000, appids[name], name))

# for arg in sys.argv[1:]: show_matches(arg) # Allow multiple args
show_matches(" ".join(sys.argv[1:])) # Allow unquoted multi-word names
