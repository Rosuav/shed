# Generate one or more XKCD 936 passwords from a specific corpus
# TODO: Make it easier to tinker with fundamental parameters:
# - case insensitivity (would case retention be an option?)
# - minimum word length - in the regex
# - word commonality threshold - in most_common()
# - number of words selected - in the join's range()
# - number of passwords generated - in the loop's range()
import collections
import re
import random
import sys

with open(sys.argv[1]) as f: corpus = f.read().lower()

words = collections.Counter(re.findall(r"\b[a-z]{3,}\b", corpus))
common = [w for w,n in words.most_common(2000)]
for _ in range(10):
	print("-".join(random.choice(common) for _ in range(4)))
