#!/usr/bin/env python3
import argparse
args = argparse.ArgumentParser(description="Line length checker")
args.add_argument("-l", "--length", default=80, type=int, help="Warn if a line exceeds this maximum")
args.add_argument("-t", "--tabs", default=8, type=int, help="Interpret tabs as this many characters")
args.add_argument("-1", "--once", action="store_true", help="Show only the one worst line for each file")
args.add_argument("files", nargs="*")
args = args.parse_args()
for fn in args.files:
	max = args.length
	msg = ""
	with open(fn, encoding="utf-8") as f:
		for i, line in enumerate(f, 1):
			line = line.rstrip("\n").expandtabs(args.tabs)
			if len(line) > max:
				msg = "%s:%d:%s" % (fn, i, line)
				if args.once: max = len(line)
				else: print(msg)
	if args.once and msg: print(msg)
