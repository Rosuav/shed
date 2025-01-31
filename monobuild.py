#!/usr/bin/env python3
# Build a C# program (most likely a library) using mono
# Add specially-formatted comments at the top to specify assemblies to import:
# //> path: /path/to/directory/full/of/dll/files
# //> import: SomeFileName
# You will also often want "//> -target:library" when modding someone else's app.
import os
import subprocess
import sys
fn = sys.argv[1]
cmd = ["mcs"]
path = []
with open(fn) as f:
	for line in f:
		line = line.strip()
		if not line.startswith("//>"): break
		if line.startswith("//> path: "):
			path.append(os.path.expanduser(line[10:]))
		if line.startswith("//> -"): cmd.append(line[4:])
		if line.startswith("//> import: "):
			# Load up an assembly that is needed
			basename = line[12:]
			for dir in path:
				tryme = dir + "/" + basename + ".dll"
				if os.path.exists(tryme):
					cmd.append("-r:" + tryme)
					break
			else:
				print("Unable to find assembly: ", basename, file=sys.stderr)
cmd.append(fn)
try: subprocess.run(cmd, check=True)
except subprocess.CalledProcessError: sys.exit(1) # It's okay to suppress the traceback, but we still want to exit 1
