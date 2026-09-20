# Fetch info from Casey CRC Breeze
import requests
import json

BASE_URL = "https://christianreformedchurchofcasey.breezechms.com/api"
API_KEY = "..."
try:
	import os
	API_KEY = os.environ["BREEZE_API_KEY"]
except:
	pass

def query(endpoint):
	r = requests.get(BASE_URL + endpoint, headers={"Api-Key": API_KEY})
	r.raise_for_status()
	return r.json()

print(json.dumps(query("/account/summary"), indent=4))

import pprint, sys; sys.displayhook = pprint.pp
