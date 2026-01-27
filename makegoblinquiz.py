# Rebuild Goblin-Quiz.md using Scryfall's API
import requests
import time
import json

def scryfall(url):
	"""Query Scryfall in an appropriate manner"""
	if not url.startswith("https://"): url = "https://api.scryfall.com/" + url
	r = requests.get(url, headers={"User-Agent": "GoblinQuiz/1.0"})
	r.raise_for_status()
	time.sleep(0.1) # 50-100ms delay between queries. We don't do very many, so 100ms is fine.
	return r.json()

def paginated(url):
	cards = []
	while "more pages":
		data = scryfall(url)
		cards.extend(data["data"])
		print("Fetched", len(cards), "of", data["total_cards"])
		if not data["has_more"]: return cards
		url = data["next_page"]

try:
	with open("goblinquiz.json") as f:
		cards = json.load(f)
except FileNotFoundError, json.JSONDecodeError:
	# May need to grab the set information too
	# sets = scryfall("sets")["data"]
	# Then do a card search.
	cards = { }
	print("Fetching funny cards...")
	cards["funny"] = paginated("cards/search?q=goblin+is:funny")
	print("Fetching less-funny cards...")
	cards["notfunny"] = paginated("cards/search?q=goblin+not:funny")
	print("Complete!")
	# Cache for efficiency if doing multiple edits
	#with open("goblinquiz.json", "w") as f:
	#	json.dump(cards, f)

PREAMBLE = """Preface
=======

Goblins are a little bit of Un-sets in the regular sets. Actually, there's
not all that many Un-set goblins, but quite a few in regular sets that are
every bit as silly as something that goes in an Un-set. Can you tell them
apart? Which cards are legal for tournament play?

<style>
del {text-decoration: none;}
del, del a {transition: all 0.75s;}
del:not(.visible) {
	color: transparent;
	background: black;
	cursor: pointer;
}
del:not(.visible) a {
	color: transparent !important;
	pointer-events: none;
	text-shadow: none;
}
</style>

The Cards
========="""
SCRIPT = """<script>
document.onclick = e => {
	if (e.target.closest("del.visible a")) return; //If you click on a link after unspoilering, don't respoiler
	const spoiler = e.target.closest("del");
	if (spoiler) spoiler.classList.toggle("visible");
}
//Dismantle that list, Fisher-Yates it into submission, and mantle it up again!
const ul = document.querySelector("ul");
const lis = [...ul.children];
for (let i = 1; i < lis.length; ++i) {
	const idx = Math.trunc(Math.random() * i);
	[lis[i], lis[idx]] = [lis[idx], lis[i]]
}
ul.append(...lis);
</script>"""

with open("goblin-quiz.md", "w") as f:
	print(PREAMBLE, file=f)
	# So. The question is, is the card tournament-legal or not?
	# For this, I'm using Scryfall's "is:funny" vs "not:funny" flag, leading to seventeen "funny"
	# cards and a couple hundred regular ones. However, I think it's only fair to exclude most of
	# the cards from Unfinity, even though they're not Acorn cards, as "Goblin Airbrusher" isn't
	# really the point of this quiz. So if the card is listed as not-funny but the set is funny,
	# I report that here so it can (most likely) be excluded.
	for card in cards["funny"]:
		if "gatherer" not in card["related_uris"]: continue
		print("- %s ~~Not legal: [%s](%s) (%s)~~" % (card["name"], card["set_name"], card["related_uris"]["gatherer"], card["released_at"][:4]), file=f)
	for card in cards["notfunny"]:
		if "gatherer" not in card["related_uris"]: continue
		if card["set_type"] == "funny": continue # Currently excluding them all.
		print("- %s ~~Legal: [%s](%s) (%s)~~" % (card["name"], card["set_name"], card["related_uris"]["gatherer"], card["released_at"][:4]), file=f)
		if card["set_type"] == "funny": print("**Funny set, probably exclude**") # If they're kept, at least mark them.
	print(SCRIPT, file=f)
print("goblin-quiz.md updated, manually edit and see if some should be removed")
