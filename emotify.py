import json
import sys
import os.path

# Can be overridden prior to calling get_emote_list if the path is wrong
EMOTE_FILE = os.path.normpath(__file__ + "/../emotes/emote_list.json")

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
		with open(EMOTE_FILE) as f:
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
		with open(EMOTE_FILE, "w") as f:
			json.dump(f, data)
	emote_list = {em["regex"]:em["id"] for em in data["emoticons"]}
	for trn in TRANSLATIONS.split("\n"):
		pat, *em = trn.split(" ")
		for e in em: emote_list[e] = emote_list[pat]
	return emote_list

def convert_emotes(msg):
	emotes = get_emote_list()
	words = msg.split()
	for i, word in enumerate(words):
		if word not in emotes: continue
		words[i] = "![%s](https://static-cdn.jtvnw.net/emoticons/v1/%s/1.0)" % (word, emotes[word])
	return " ".join(words)

def validate_translations():
	# Check that the TRANSLATIONS mapping doesn't violate regex rules
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
	for msg in sys.argv[1:]:
		print(convert_emotes(msg))
	if len(sys.argv) <= 1:
		validate_translations()
