import json
import sys
import os.path

# Can be overridden prior to calling get_emote_list
EMOTE_PATH = os.path.normpath(__file__ + "/../emotes")

# Only a handful of emotes actually make use of the fact that the check is a
# regex. We don't use regexes, so instead, we translate those few emotes into
# a few actual strings that would match. Several have the "-?" optional hyphen
# or a bit of alternation, and all of them have at least one escaped special.
TRANSLATIONS = """
\\:-?\\) :) :-)
\\:-?\\( :( :-(
\\:-?D :D :-D
\\&gt\\;\\( >(
\\:-?[z|Z|\\|] :-z :-Z :-| :z :Z :|
[oO](_|\\.)[oO] o_o O_O o.o O.O
B-?\\) B-) B)
\\:-?(o|O) :-o :-O :o :O
\\&lt\\;3 <3
\\:-?[\\\\/] :-\\ :-/ :\\ :/
\\;-?\\) ;) ;-)
\\:-?(p|P) :-p :-P :p :P
\\;-?(p|P) ;-p ;-P ;p ;P
R-?\\) R) R-)
"""
emote_list = None
def get_emote_list():
	global emote_list
	if emote_list: return emote_list
	try:
		with open(EMOTE_PATH + "/emote_list.json") as f:
			data = json.load(f)
	except FileNotFoundError:
		print("Downloading emote list...", file=sys.stderr)
		import requests
		# TODO: Add header "Accept: application/vnd.twitchtv.v5+json" and
		# "Client-ID: xxxxxx" where the latter comes from Mustard Mine etc
		# TODO: List BTTV and FFZ emotes somehow (maybe snoop traffic on
		# the main site to find out where to get the list)
		# https://api.betterttv.net/2/emotes - global BTTV emotes
		# https://api.betterttv.net/2/frankerfacez_emotes/global - global FFZ emotes
		# https://api.betterttv.net/2/channels/devicat - DeviCat BTTV emotes
		# https://api.betterttv.net/2/frankerfacez_emotes/channels/54212603 - DeviCat FFZ emotes
		req = requests.get("https://api.twitch.tv/kraken/chat/emoticons")
		req.raise_for_status()
		data = req.json()
		with open(EMOTE_PATH + "/emote_list.json", "w") as f:
			json.dump(data, f)
	emote_list = {em["regex"]: "https://static-cdn.jtvnw.net/emoticons/v1/%s/1.0" % em["id"]
		for em in reversed(data["emoticons"])}
	for trn in TRANSLATIONS.split("\n"):
		pat, *em = trn.split(" ")
		for e in em: emote_list[e] = emote_list[pat]
	return emote_list

def load_bttv(*channels):
	"""Load BTTV emotes for zero or more channels

	If no channels are specified, loads only the global emotes. Otherwise,
	emotes for the named channels (by username) will also be loaded.

	Mutates the emote list used by convert_emotes().
	"""
	emote_list = get_emote_list()
	try:
		with open(EMOTE_PATH + "/bttv.json") as f:
			data = json.load(f)
	except FileNotFoundError:
		print("Downloading BTTV emote list...", file=sys.stderr)
		import requests
		# https://api.betterttv.net/2/channels/devicat - DeviCat BTTV emotes
		req = requests.get("https://api.betterttv.net/2/emotes")
		req.raise_for_status()
		data = req.json()
		template = data["urlTemplate"].replace("{{image}}", "1x")
		if template.startswith("//"): template = "https:" + template
		data = {em["code"]: template.replace("{{id}}", em["id"])
			for em in data["emotes"]}
		with open(EMOTE_PATH + "/bttv.json", "w") as f:
			json.dump(data, f)
	emote_list.update(data)

def load_ffz(*channels):
	"""Load FrankerFaceZ emotes for zero or more channels

	If no channels are specified, loads only the global emotes. Otherwise,
	emotes for the named channels (by user ID) will also be loaded.

	Mutates the emote list used by convert_emotes().
	"""

def convert_emotes(msg):
	emotes = get_emote_list()
	words = msg.split()
	for i, word in enumerate(words):
		if word not in emotes: continue
		words[i] = "![%s](%s)" % (word, emotes[word])
	return " ".join(words)

def validate_translations():
	# Check that the TRANSLATIONS mapping doesn't violate regex rules
	# Basically, this will catch typos like expecting ":)" to match "\\:-?\\(" etc.
	import re
	count = 0
	for trn in TRANSLATIONS.split("\n"):
		if not trn: continue
		pattern, *emotes = trn.split(" ")
		pat = re.compile(pattern) # Validate the RE format itself
		for em in emotes:
			em = em.replace("<", "&lt;").replace(">", "&gt;") # Convert to HTMLish form :(
			m = re.match(pat, em)
			if not m: print("Failed to match:", pattern, em)
			elif m.group(0) != em: print("Failed to consume all:", pattern, em)
		count += 1
	print(count, "emote patterns tested.")

if __name__ == "__main__":
	load_bttv()
	for msg in sys.argv[1:]:
		print(convert_emotes(msg))
	if len(sys.argv) <= 1:
		validate_translations()
