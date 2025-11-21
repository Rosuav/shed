# Search the C include file for options that aren't in Python's socket module
# There will likely be a lot of false positives as this does not respect #if
# directives; however, it will attempt to output them.
import socket
import re
import sys

showall = "--all" in sys.argv

for filename in "in.h", "in6.h":
	with open("/usr/include/linux/" + filename) as f:
		conditions = []
		cond_printed = 0 # Number of current conditions that have been printed out
		for line in f:
			line = line.strip() # Indentation doesn't matter here, also strip off the trailing newline
			if m := re.match(r"#\s*define\s+([A-Z_0-9]+)\s+(\d+)\s*(|/\*.*\*/\s*|//.*)$", line):
				# We found a define! Is it already in the socket module?
				if not showall and hasattr(socket, m[1]): continue
				for cond in conditions[cond_printed:]:
					print(cond)
				cond_printed = len(conditions)
				print("Found a define:", m[1], m[2], m[3])
			elif line.startswith("#if"):
				# Add this to the stack, but don't print it yet
				conditions.append(line)
			elif line.startswith("#elif"):
				# If the current #elif label has not been printed, this one can simply
				# supersede it. However, if the most recent label is the original #if,
				# both need to be retained. (We assume legal code here, ie there won't
				# be an #else followed by #elif, or an #elif without an #if.)
				if conditions[-1].startswith("#elif") and cond_printed < len(conditions):
					conditions.pop()
				conditions.append(line)
			elif line.startswith("#else"):
				# Similarly to the above, discard an unprinted #elif.
				if conditions[-1].startswith("#elif") and cond_printed < len(conditions):
					conditions.pop()
				conditions.append(line)
			elif line.startswith("#endif"):
				# Discard any unprinted #elif or #else. Then if the #if got printed,
				# print the #endif; but otherwise, discard it.
				while conditions[-1].startswith(("#elif", "#else")):
					conditions.pop()
				if cond_printed >= len(conditions):
					print(line)
				conditions.pop()
				cond_printed = min(cond_printed, len(conditions))
