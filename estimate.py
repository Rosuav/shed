import sys
from fractions import Fraction
from math import log10

digits = sys.argv[1]
print("Estimating 0.%s as a fraction..." % digits)

def vulgarize(rpt):
	"""Calculate a vulgar fraction for a given continued fraction"""
	f = Fraction(0)
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

frac = [0]
residue = orig = float("0." + sys.argv[1])
for _ in digits: # No more than six terms for a six-digit number - no point
	t = 1/residue
	frac.append(int(t))
	residue = t - int(t)
	vulg = vulgarize(frac)
	error = magnitude((vulg - orig) / orig)
	print("%15s %+6.2f %r" % (vulg, error, frac))
	if residue == 0: break # If it's getting arbitrarily close, that's fine, but if it actually hits zero, stop before crashing.
