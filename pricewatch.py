# Scrape Woolies Online to find out the price of certain items
# TODO: Also scrape Coles, maybe Aldi too, for comparisons
# TODO: Save to a file to simplify price tracking
# Note that Coles is a pain to scrape. Would need to poke around
# to find exactly how it's doing its AJAX requests; naive tests
# produced poor results.

import requests
# import bs4
import urllib.parse

def get_prices(search):
	"""Get prices for a particular search term

	Returns a list of tuples of ('Woolworths', 'Item Name', 123400)
	where the price is integer cents. Future expansion may have
	other providers listed with the same item(s).

	Currently scrapes only the first page of results, so don't
	ask for too much
	"""
	r = requests.post("https://www.woolworths.com.au/apis/ui/Search/products", json={
		"SearchTerm": search,"PageSize":36,"PageNumber":1,"SortType":"TraderRelevance","IsSpecial":False,"Filters":[],"Location":"/shop/search/products?searchTerm=cadbury%20drinking%20chocolate"})
	r.raise_for_status()
	for product in r.json()["Products"]:
		# There's an array of... product groups? Maybe?
		print(product["Name"])

get_prices("cadbury drinking chocolate")
get_prices("v energy drink")
get_prices("mother energy drink")
get_prices("monster energy drink")
