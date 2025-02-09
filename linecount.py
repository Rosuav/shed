# Group lines by content and report how many times each one shows up
# Should retain order, but group everything into the first instance of it
import collections, sys
c = collections.Counter(sys.stdin)
max = c.most_common(1)[0][1] # The most copies of any given line
fmt = "[%%%dd] %%s" % len(str(max))
for line, count in c.items():
	print(fmt % (count, line), end="")
