import sys
from fractions import Fraction
from math import log10

digits = sys.argv[1]
print("Estimating %s as a fraction..." % digits)

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

frac = []
orig = Fraction(digits)
residue = 1/orig
while residue:
	t = 1/residue
	frac.append(int(t))
	residue = t - int(t)
	vulg = vulgarize(frac)
	error = magnitude((vulg - orig) / orig)
	print(f"%{len(digits)*2}s %+6.2f %r" % (vulg, error, frac))
