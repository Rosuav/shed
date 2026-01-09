# Explore (the current branch of) a git repo to show which files get the most movement
# TODO: Handle renames as touching both the old and new names
import collections
import subprocess

proc = subprocess.run(["git", "log", "--pretty=format:# %h %an", "--numstat"], check=True, capture_output=True, text=True)
if proc.stderr:
	import sys
	print(proc.stderr, file=sys.stderr)
	sys.exit(1)

# Each commit starts with a line identifying the commit; the "--pretty" line determines this, and
# we use the hash sign to recognize it. TODO: Allow categorizing by this line?
# Then within a commit, there will be zero or more lines naming files and giving their diffs
# Finally, for some reason, there's a blank line. It isn't there if "--pretty=oneline". Not sure why.
active_files = collections.defaultdict(lambda: [0, 0, 0])
for line in proc.stdout.split("\n"):
	if not line: continue
	if line.startswith("#"):
		# It's a commit.
		# Not currently using this separation, we just count every file we see.
		continue;
	added, removed, filename = line.split("\t")
	# What's the best way to handle binary files?
	if added == "-": added = 0
	if removed == "-": removed = 0
	stats = active_files[filename]
	stats[0] += 1
	stats[1] += int(added)
	stats[2] += int(removed)
files = list(active_files.items())
files.sort(key=lambda pair: -pair[1][0])
print("Top ten most-active files are:")
print("Commits |  Added  | Removed | File name")
for fn, [commits, added, removed] in files[:10]:
	print("%7d | %7d | %7d | %s" % (commits, added, removed, fn))
