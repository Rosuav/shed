# Build a JSON command blob for MrsOEF5's !artist command
import sys
import json
import odf.opendocument # ImportError? pip install odfpy
from odf.table import Table, TableRow, TableCell

doc = odf.opendocument.load(sys.argv[1])
sheet = doc.spreadsheet.getElementsByType(Table)[0]
cols = { }
msgs = []

def expand(cells):
	# ODS cells can have a repeat count. Logically, we should just duplicate them out.
	for cell in cells:
		for _ in range(int(cell.getAttribute("numbercolumnsrepeated") or 1)):
			yield cell

for row in sheet.getElementsByType(TableRow):
	data = { }
	for pos, val in enumerate(expand(row.getElementsByType(TableCell))):
		data[cols.get(pos, pos)] = str(val)
	if not cols:
		# Save the header names and use them for mapping
		cols = data
		continue
	if not data["name"]: continue
	link = data["link"]
	if link == "no stream" or link == "No raid": link = "https://mrsoef5.com/atc/" + data["name"] + " (link won't work yet)"
	if link.startswith("Twitch.tv/"): link = "https://t" + link[1:]
	link = link.replace("www.twitch.tv", "twitch.tv") # Brevity helps in chat
	msgs.append("maayaBrush %s is one of our #100Artists %s" % (data["name"], link))

json.dump({"message": msgs, "mode": "random", "access": "vip"}, sys.stdout)
print()
