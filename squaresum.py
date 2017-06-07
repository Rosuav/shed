# According to http://youtu.be/NoRjwZomUK0, the sum of the first 24 squares is,
# itself, a square (70 squared). What other such situations are there?

sum = 0
for val in range(10**10):
	sum += val * val
	sqrt = int(sum ** 0.5)
	if sqrt ** 2 == sum:
		print("Squares up to %d² == %d²" % (val, sqrt))
	elif val % 1000000 == 0:
		print(val, end="\r")


# Huh. Aside from the trivial cases of 0² and 1², the original example is
# actually the only one that exists at anything less than ridiculous
# sizes. There's not going to be an elegant square of consecutive squares.
