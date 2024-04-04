# Estimate the average stats of a ruler in an EU4 republic
# Monarchies get random stats for the life of the monarch, but republics start with 6-pointers that improve.
# Assumes that you reelect the same person until he dies, then pick another and start over.
# Does not take bonus stats into account. Does not factor in the extra death chance if he's also a general.
# Definitely doesn't consider random deaths by event.
# The output is "as if" the stats were all that value - a 3.00 average is like having a 3/3/3 monarch for life.
RESULTS = """

Term |   35 |   36 |   37 |   38 |   39 |   40 |   41 |   42 |   43 |   44 |   45 |   46 |   47 |   48 |   49 |   50 |   51 |   52 |   53 |   54 |   55
   2 | 4.90 | 4.87 | 4.83 | 4.79 | 4.74 | 4.69 | 4.66 | 4.63 | 4.59 | 4.55 | 4.51 | 4.46 | 4.40 | 4.34 | 4.27 | 4.20 | 4.16 | 4.11 | 4.05 | 3.99 | 3.92
   3 | 4.48 | 4.43 | 4.39 | 4.34 | 4.29 | 4.23 | 4.19 | 4.15 | 4.11 | 4.06 | 4.00 | 3.94 | 3.88 | 3.81 | 3.74 | 3.67 | 3.62 | 3.56 | 3.50 | 3.43 | 3.36
   4 | 4.11 | 4.06 | 4.01 | 3.96 | 3.90 | 3.85 | 3.80 | 3.76 | 3.70 | 3.65 | 3.60 | 3.54 | 3.47 | 3.41 | 3.34 | 3.27 | 3.22 | 3.16 | 3.11 | 3.04 | 2.98
   5 | 3.79 | 3.74 | 3.69 | 3.63 | 3.58 | 3.52 | 3.48 | 3.43 | 3.38 | 3.33 | 3.28 | 3.22 | 3.16 | 3.10 | 3.04 | 2.98 | 2.94 | 2.89 | 2.84 | 2.79 | 2.74
   6 | 3.51 | 3.46 | 3.41 | 3.36 | 3.31 | 3.26 | 3.22 | 3.17 | 3.13 | 3.08 | 3.03 | 2.98 | 2.93 | 2.88 | 2.83 | 2.78 | 2.74 | 2.70 | 2.65 | 2.61 | 2.56
   7 | 3.28 | 3.24 | 3.19 | 3.15 | 3.10 | 3.05 | 3.02 | 2.98 | 2.93 | 2.89 | 2.85 | 2.80 | 2.76 | 2.72 | 2.67 | 2.63 | 2.59 | 2.56 | 2.52 | 2.48 | 2.43
   8 | 3.10 | 3.06 | 3.02 | 2.98 | 2.93 | 2.89 | 2.86 | 2.82 | 2.78 | 2.75 | 2.71 | 2.67 | 2.63 | 2.59 | 2.55 | 2.51 | 2.48 | 2.45 | 2.41 | 2.37 | 2.33
   9 | 2.95 | 2.91 | 2.88 | 2.84 | 2.80 | 2.77 | 2.73 | 2.70 | 2.66 | 2.63 | 2.59 | 2.56 | 2.52 | 2.49 | 2.46 | 2.42 | 2.39 | 2.36 | 2.32 | 2.29 | 2.26
  10 | 2.83 | 2.80 | 2.76 | 2.73 | 2.69 | 2.66 | 2.62 | 2.59 | 2.56 | 2.53 | 2.50 | 2.47 | 2.44 | 2.41 | 2.38 | 2.34 | 2.31 | 2.28 | 2.26 | 2.24 | 2.21
  11 | 2.73 | 2.70 | 2.67 | 2.63 | 2.60 | 2.57 | 2.54 | 2.51 | 2.48 | 2.46 | 2.43 | 2.40 | 2.37 | 2.34 | 2.31 | 2.28 | 2.25 | 2.23 | 2.21 | 2.19 | 2.17
  12 | 2.64 | 2.61 | 2.58 | 2.55 | 2.52 | 2.49 | 2.47 | 2.44 | 2.42 | 2.39 | 2.36 | 2.34 | 2.31 | 2.28 | 2.26 | 2.23 | 2.21 | 2.19 | 2.18 | 2.16 | 2.14
  13 | 2.56 | 2.54 | 2.51 | 2.48 | 2.46 | 2.43 | 2.41 | 2.38 | 2.36 | 2.33 | 2.31 | 2.28 | 2.26 | 2.24 | 2.21 | 2.19 | 2.18 | 2.16 | 2.14 | 2.13 | 2.11
  14 | 2.50 | 2.48 | 2.45 | 2.42 | 2.40 | 2.37 | 2.35 | 2.33 | 2.31 | 2.28 | 2.26 | 2.24 | 2.22 | 2.20 | 2.18 | 2.16 | 2.15 | 2.13 | 2.12 | 2.10 | 2.08

"""

def estimate_stats(starting_age, term):
	stats = 6 # 4/1/1, 1/4/1, 1/1/4
	tot_stats = years = 0
	alive = 1.0
	in_office = 0
	lifetimes = []
	for age in range(starting_age, 100): # Assume they'll definitely die by age 100 (which isn't strictly true)
		tot_stats += stats; years += 1
		age_bracket = [1, 1, 1, 1, 2, 4, 10, 50, 300, 1000][age // 10]
		survives_today = 1 - (4 * age_bracket) / 182500
		survives_this_year = survives_today ** 365
		lifetimes.append((tot_stats, years, alive * (1 - survives_this_year)))
		alive *= survives_this_year
		in_office += 1
		if in_office >= term:
			in_office = 0
			if stats < 12: stats += 3 # Until you hit 6/3/3, all three stats go up
			elif stats < 18: stats += 2 # And until you hit 6/6/6, the other two go up. After that, you stagnate.
	avg = sum(stats / years * chance for stats, years, chance in lifetimes)
	# print(f"After taking office at {starting_age} years old, average stats {avg}.")
	return avg

age_range = range(35, 56)
print("Term | " + " | ".join("%4d" % a for a in age_range))
for t in range(2, 15):
	print("%4d" % t, end="")
	for a in age_range:
		print(" | %4.2f" % (estimate_stats(a, t) / 3), end="")
	print()

