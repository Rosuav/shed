# Mana curve prediction/stats
"""
Gavin Verhey says: "More than any other way, I have seen a larger number of
Limited games won by simply curving out with drops on turns two through five
than any other method. If you hit your drops each turn and your opponent
stumbles, they're quickly going to be put on the back foot."

http://magic.wizards.com/en/articles/archive/beyond-basics/how-build-mana-curve-2017-05-18

Okay. So let's suppose you JUST focus on that. How would you build a deck to
have the best possible chances of hitting creatures turns two through five?

Let's find out.
"""

# A deck is represented by the mana cost distribution of its spells. The land
# count is in the last slot, and is accessed as deck[-1].

# Average figures from Gavin's article
gavin = [0, 1, 5, 4, 3, 2, 1, 17]

def analyze(deck, tag="", decksize=40):
	if tag:
		print("---- %s ----" % tag)
		print("%d lands, %d creatures, %d other spells" % (
			deck[-1], sum(deck[:-1]), decksize-sum(deck)
		))

analyze(gavin, "Gavin's averages")
