# Calculate your odds of surviving the Murder Trivia Party chalices game
from collections import defaultdict
import sys

try:
	CHALICES = int(sys.argv[1])
except (IndexError, ValueError):
	CHALICES = 8

chances = {0: 1.0} # Initially, you have 100% chance of having no placed pellets.
total_chances = []
for poison in range(CHALICES): # though you won't normally see the full set
	# Add another poison pellet.
	newchance = defaultdict(float)
	for poisoned, prob in chances.items():
		# There are 'poisoned' chalices already poisoned when this pellet
		# gets added. Thus there are that many chances out of CHALICES to
		# re-poison a poisoned chalice.
		if poisoned:
			newchance[poisoned] += prob * poisoned / CHALICES
		# The remaining probability is that you poisoned a new one.
		true_brew = CHALICES - poisoned
		if true_brew:
			newchance[poisoned + 1] += prob * true_brew / CHALICES
		# This will always add up to the original probability.
		# The total probability in the dictionary will always equal 1.0.
	chances = newchance
	print("With %d poison pellets, your chances are:" % (poison + 1))
	tot = 0.0
	for poisoned, prob in sorted(chances.items()):
		survive = 100 - poisoned * 100.0 / CHALICES
		print("%5.2f%% chance of %d poisoned for %5.2f%% survival chance ==> %5.2f%%"
			% (prob*100, poisoned, survive, survive * prob))
		tot += survive * prob
	print("-- total probability of survival %5.2f" % tot)
	total_chances.append(tot)

print("Summary:")
print(" ", "  ".join(" %2s   " % (n+1) for n in range(CHALICES)))
print(" ", "  ".join("%5.2f%%" % c for c in total_chances))

# Summary:
#     1       2       3       4       5       6       7       8
#   87.50%  76.56%  66.99%  58.62%  51.29%  44.88%  39.27%  34.36%
