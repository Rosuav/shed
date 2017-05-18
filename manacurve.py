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

# Note: We assume Python 3 here. You may be able to use Python 2 if you use
# from __future__ import print_function, division
from collections import defaultdict

# A deck is represented by the mana cost distribution of its spells. The land
# count is in the last slot, and is accessed as deck[-1].

# Average figures from Gavin's article
gavin = [0, 1, 5, 4, 3, 2, 1, 17]

# Probability distribution: a given tuple of drawn cards has a certain
# chance of occurring, given as a float in range [0.0, 1.0].
# The tuple corresponds to the incoming deck (including that [-1] is
# the land count).
def draw(deck, chances=None):
	"""Draw a card.

	The new card could be any CMC that's in your deck, as long as
	we haven't already seen all of that CMC. (This includes lands.)
	The chances of it being such are based on the remaining cards.
	As such, the chances of any given pattern occurring are the
	product of the chances of the prior pattern having occurred and
	the chance of a particular CMC being drawn.

	Constructs a new dictionary with the probabilities post-draw.
	"""
	if chances is None:
		# Before you draw your opening hand, you have a 100% chance of
		# having no cards. (Note that we are looking at what cards
		# you've seen, not what's still in your hand.)
		# Note that this function will fail in strange ways if the
		# tuples in the dict keys don't have the same length as the
		# given deck. So just pass None the first time, and let this
		# create the correct dictionary.
		chances = {tuple(0 for _ in deck): 1.0}
	newchance = defaultdict(float)
	for cards, prob in chances.items():
		# There are len(deck) possible draws (or possibly less, if
		# some of the CMCs have already been exhausted - particularly
		# if some don't actually get represented).
		next_draw = [have - seen for have, seen in zip(deck, cards)]
		cards_left = sum(next_draw)
		if cards_left <= 0:
			raise ValueError("No more cards to draw!")
		cards = list(cards) # It's easier to just mutate...
		for idx, draw in enumerate(next_draw):
			if not draw: continue
			chance = draw / cards_left
			# Really, I should just construct a new tuple from the
			# old one, incrementing one value. But I can't be
			# bothered. Lists are very handy. :)
			cards[idx] += 1
			newchance[tuple(cards)] += chance
			cards[idx] -= 1
	return newchance

def analyze(deck, tag="", decksize=40):
	# Add "non-curve spells" as deck[-2]
	deck.insert(-1, decksize-sum(deck))
	if tag:
		print("---- %s ----" % tag)
		print("%d lands, %d creatures, %d other spells" % (
			deck[-1], sum(deck[:-2]), deck[-2]
		))
	chances = None
	for hand_size in range(7): # 8 on the draw
		chances = draw(deck, chances)
	print(chances) # Opening hand

analyze(gavin, "Gavin's averages")
