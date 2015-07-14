# http://www.1728.org/ellipse.htm
# I suspect the code was ported from BASIC to JavaScript, and then I
# ported it to Python. Still, arithmetic works just the same... and
# it's probably been IEEE double precision all the way.
from __future__ import division
import math
try: input = raw_input
except NameError: pass
pival = math.pi
while True:
	print("")
	prh=int(input("Perhelion:  ") or 147098291)
	aph=int(input("Aphelion:   ") or 152098233)
	if prh>aph: prh, aph = aph, prh
	maj=(aph+prh); print("Major axis: %s"%maj)
	ecc=(aph-prh)/(aph+prh); print("Eccentric:  %s"%ecc)
	min=maj*math.sqrt(1-(ecc*ecc)); print("Minor axis: %s"%min)
	smaj=maj/2; smin=min/2;
	per=pival*3*(smaj+smin)-pival*math.sqrt(10*smaj*smin+3*smaj*smaj+3*smin*smin); print("Perimeter:  %s"%per)
	area=(pival*maj*min)/4; print("Area:       %s"%area)
