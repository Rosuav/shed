def parse_roll_test(test):
	# Parse the result of 'roll test' from Minstrel Hall
	dist = {}
	total = 0
	for line in test.split("\n"):
		if ":" in line:
			val, prob = line.split(":")
			dist[val] = int(prob)
			total += int(prob)
	# Parsing complete. We now have a mapping of result to number of instances,
	# and a total result count. So dist[X]/total == probability of X occurring,
	# for any X.
	return dist, total

def chisq(dist, total):
	expected = total / len(dist)
	error = 0
	for result, count in dist.items():
		error += (count - expected) ** 2 / expected
	print("χ² =", error)


chisq(*parse_roll_test("""
1: 10135
2: 9971
3: 9774
4: 9849
5: 10059
6: 9936
7: 9990
8: 10027
9: 9917
10: 10054
11: 10202
12: 10008
13: 10136
14: 10060
15: 10012
16: 9941
17: 10007
18: 9956
19: 10096
20: 9870
"""))
