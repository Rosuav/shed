import collections
import re

with open("/usr/share/dict/words") as f:
	words = [w.strip() for w in f]

dot = "[qwertyuiopasdfghjklzxcvbnm]"
lastpat = "^$"
while True:
	try: pat = input("Pattern> ")
	except EOFError: break
	if pat == "": break
	if len(pat) > 1 and pat[0] != "~": lastpat = pat
	for ltr in pat:
		if ltr.isalpha(): dot = dot.replace(ltr, "")
	regex = "^" + lastpat.replace(".", dot) + "$"
	w = [w for w in words if re.match(regex, w)]
	print(len(w), "words")
	if len(w) < 20: print(*w)
	freq = collections.Counter("".join(w))
	for l, c in freq.most_common(8):
		if l in dot: print(l, c)
