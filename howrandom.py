# How random IS that function?
# Given a function which returns a random integer in range(n),
# figure out whether it seems "random enough".
from collections import Counter
import itertools

VERBOSE = False # Set to True for a full listing of every entry

def analyze_counter(label, c, n):
	scale = c.total() / n
	print("%s (%d possibilities, avg %s):" % (label, n, scale))
	scale /= 100
	first = True
	for which, count in c.most_common():
		if first or VERBOSE: print("\t%s - %d (%5.2f%%)" % (which, count, count / scale))
		first = False
	if not VERBOSE:
		# Print out the last one
		print("\t%s - %d (%5.2f%%)" % (which, count, count / scale))

def analyze_groups(pool, width, n):
	it = [pool]
	for i in range(1, width):
		it.append(itertools.cycle(pool))
		# Rotate the sequence around
		for _ in range(i): next(it[-1])
	analyze_counter("Groups of %d" % width, Counter("-".join(str(x) for x in z) for z in zip(*it)), n ** width)

def analyze_diceroll(randbelow, max, limit):
	pool = [randbelow(max) + 1 for _ in range(1048576)]
	analyze_counter("%d-sided dice" % max, Counter(pool), max)
	for i in range(2, limit + 1):
		analyze_groups(pool, i, max)


def analyze(label, randbelow):
	print()
	print(label)
	print("=" * len(label))

	# Random bits (labelled differently)
	pool = ["HT"[randbelow(2)] for _ in range(1048576)]
	analyze_counter("Coin flips", Counter(pool), 2)
	for i in range(2, 5):
		analyze_groups(pool, i, 2)
	
	# Dice rolls
	analyze_diceroll(randbelow, 6, 4)
	analyze_diceroll(randbelow, 20, 3)
	analyze_diceroll(randbelow, 100, 1)

import random
analyze("random.randrange", random.randrange)
analyze("Random(1234).randrange", random.Random(1234).randrange)
