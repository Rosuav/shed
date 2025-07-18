# Construct a "wiki notebook" just like Will's but populated from the wiki
# https://moonlighter.gamepedia.com/Special:Export
# Add pages from category "Items"
# Current revision only, save as file
# python3 moonlighter.py Moonlighter+Wiki-timestamp.xml >moonlighter.txt

# List items grouped by culture, ordered by base value
# For each item, show the best possible sell price for neutral popularity
# == Base Value * 1.1, and subtract 1 if name ends "+1"

import re
import sys
from collections import defaultdict
import xml.etree.ElementTree as ET
with open(sys.argv[1]) as f: data = f.read()
# Hack: Clear out the default namespace to make parsing easier
data = "<mediawiki>\n" + data.split("\n", 1)[1]
tree = ET.fromstring(data)
cultures = defaultdict(list)
for node in tree:
	if node.tag != "page": continue
	page = node.find("title").text
	info = node.find("revision/text").text
	if not info: print(page)
	if m := re.search("{{(Item|Gear) Page(.*)", info, re.S):
		lines = m[2].split("\n")
	else: continue
	stats = {}
	for line in lines:
		if not line: continue
		if line == "}}": break
		if "=" in line:
			key, val = line.split("=", 1)
			stats[key.replace("|", "").strip()] = val.strip()
	if "value" not in stats: continue
	culture = stats.get("culture", "")
	culture = re.sub(r"<!--.*-->", "", culture).strip() or "Unknown" # Remove comments and whites
	# NOTE: The wiki no longer has separate pages for the NG+ variants.
	# Instead, the NG+ variant is simply priced at ceil(x*5.6) which is within 1 gold of the
	# values that I was previously getting.
	# if page.endswith(" +1"): culture += " +1"
	stats["page"] = page
	cultures[culture].append(stats)

def intify(x): # Intify for sorting; unknowns get sorted to the bottom.
	try: return int(x)
	except ValueError: return -1

for culture, items in cultures.items():
	items.sort(key=lambda item: (-intify(item["value"]), item["page"]))
	print(culture)
	for item in items:
		try:
			base = int(item["value"])
			sale = base * 11 // 10 # I'm flooring, but it's possible that ceil is actually correct (??)
			if culture.endswith(" +1"): sale -= 1
		except ValueError:
			sale = "?"
		print("\t%6s %s" % (sale, item["page"]))
