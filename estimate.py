import sys
from fractions import Fraction
from math import log10

def vulgarize(rpt):
	"""Calculate a vulgar fraction for a given continued fraction"""
	f = Fraction(0)
	if tuple(rpt) == (0,): return f # Avoid dividing by zero
	for term in reversed(rpt):
		f = 1 / (term + f)
	return 1/f

def magnitude(x):
	"""Give an indication of the magnitude of a number

	Bigger numbers have bigger magnitudes, and you can see the direction
	of the number in the result (so -4 is further from zero than +2 is).
	"""
	if x < 0: return -log10(-x)
	if x == 0: return 0
	return log10(x)

digits = sys.argv[1]
if "," in digits:
	digits = [int(d.strip()) for d in digits.split(",")]
	frac = vulgarize(digits)
	print(frac, digits, float(frac))
	sys.exit(0)
print("Estimating %s as a fraction..." % digits)

frac = []
orig = Fraction(digits)
residue = 1/orig
accuracy = []
while residue:
	t = 1/residue
	frac.append(int(t))
	residue = t - int(t)
	vulg = vulgarize(frac)
	error = magnitude(vulg - orig)
	print(f"%{len(digits)*2}s %+6.2f %r" % (vulg, error, frac))
	if vulg != orig:
		# Estimate the accuracy by showing, in effect, how many
		# correct digits there are before there's an error.
		# (Accuracy becomes immeasurable for the last term.)
		accuracy.append(-log10(abs(vulg - orig)))

if "--graph" in sys.argv:
	import matplotlib.pyplot as plt
	# Convert accuracy into accuracy-gained-last-time
	# From three terms [a, b, c], we look at the accuracy gained by
	# adding term b, and then plot that alongside c.
	from operator import sub
	accuracy = [0] + list(map(sub, accuracy, [0] + accuracy[:-1]))
	# Different y-scales - see https://matplotlib.org/gallery/api/two_scales.html
	fig, ax1 = plt.subplots()
	ax1.set_xlabel("N Terms")
	ax1.set_ylabel("Term", color="tab:red")
	ax1.set_yscale("log") # Since accuracy is already, in effect, logarithmic, do the same here.
	ax1.plot(frac, color="tab:red")
	ax1.tick_params(axis="y", labelcolor="tab:red")
	ax2 = ax1.twinx()
	ax2.set_ylabel("Accuracy gained", color="tab:blue")
	ax2.plot(accuracy, color="tab:blue")
	ax2.tick_params(axis="y", labelcolor="tab:blue")
	fig.tight_layout()
	plt.show()
