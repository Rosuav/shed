# Scrape Woolies Online to find out the price of certain items

# Would be nice to track Coles and Aldi as well, but Aldi don't
# show prices, and Coles is a pain to scrape. Would need to do
# some seriously hairy research to find exactly how it's doing
# its AJAX requests; naive tests produced poor results.

import requests
# import bs4
import urllib.parse
import json
import time

price_history = {}
try:
	with open("_pricewatch.json") as f:
		price_history = json.load(f)
except OSError:
	pass

# Leave room to store Coles and/or Aldi prices later
woolies = price_history.setdefault("Woolies", {})

# Get a consistent timestamp for the sake of stability
now = int(time.time())

for search in [
	"cadbury drinking chocolate",
	"v blue energy drink",
	"mother berry energy drink",
	# "monster assault energy drink", # Not carried by Woolies?
]:
	r = requests.post("https://www.woolworths.com.au/apis/ui/Search/products", json={"SearchTerm": search})
	r.raise_for_status()
	for group in r.json()["Products"]:
		# There's an array of... product groups? Maybe? Not sure what to
		# call them; they're shown to the user as a single "product", but
		# you can pick any of the items to actually buy them. For example,
		# an item available in multiple sizes is shown as one "item" with
		# multiple "Add to Cart" buttons.
		# print("\t" + group["Name"]) # Usually irrelevant
		for product in group["Products"]:
			if product["IsBundle"]: continue # eg "Winter Warmers Bundle" - irrelevant to this search
			id = str(product["Stockcode"]) # Unique identifier - must be a string (gets saved to JSON)
			desc = product["Name"] + " " + product["PackageSize"]
			cents = int(product["Price"] * 100)
			price = "$%.2f" % product["Price"]
			if product["HasCupPrice"]: price += " (" + product["CupString"] + ")"
			if id in woolies:
				# Item we've already seen. Compare price to last time.
				info = woolies[id]
				delta = cents - info["price_cents"]
				if delta > 0: color = "\x1b[1;31m" # Price gone up
				elif delta < 0: color = "\x1b[1;32m" # Price gone down
				else: color = "" # Price same as last seen
				# TODO: Show the previous price, for comparison
				if delta:
					# Price has changed, so add it to the history.
					info["history"][now] = cents
			else:
				# New item. Show it in green.
				color = "\x1b[32m"
				woolies[id] = info = {"history": {now: cents}}
			print("%s[%s] %-45s %s\x1b[0m" % (color, product["Stockcode"], desc, price))
			info["desc"] = desc
			info["price_cents"] = cents
			info["seen"] = now

with open("_pricewatch.json", "w") as f:
	json.dump(price_history, f, indent=4)
