# Monitor a GoFundMe page and report new donations
import json
import time
import textwrap
from pprint import pprint
import requests

POLL_INTERVAL = 60 # seconds
URL = "https://www.gofundme.com/f/MarvinStream" # TODO: Parameterize

seen = {}

def ping():
	r = requests.get(URL)
	if r.status_code != 200:
		print("\x1b[1;31mGot unexpected status code %s\x1b[0m" % r.status_code)
		return
	# There's a script tag that dumps great data straight into the global object.
	text = r.text.split("window.initialState = ", 1)[1]
	text = text.replace("&#039;", "'") # TODO: Decode properly
	info = json.JSONDecoder().raw_decode(text)[0]
	campaign = info["feed"]["campaign"][0]
	currency = campaign["currencycode"]
	total = "%d %s" % (campaign["current_amount"], currency)
	if "" not in seen:
		print("Current total:", total)
	else:
		if seen[""] != total: print("\x1b[1;32mNew total: " + total + "\x1b[0m")
	seen[""] = total
	# Scan the donations oldest first. New ones will get added underneath.
	for dono in reversed(info["feed"]["donations"]):
		id = dono["donation_id"]
		if id in seen:
			continue
		seen[id] = time.time()
		print("%s donated %d %s" % (dono["name"], dono["amount"], currency))
		if dono["comment"]:
			# TODO: Wrap to within the display width if available
			print(textwrap.fill(dono["comment"], initial_indent="-- ", subsequent_indent="-- "))

while True:
	ping()
	time.sleep(POLL_INTERVAL)
