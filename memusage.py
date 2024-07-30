from __future__ import print_function
import sys
import time
last = float("inf")
log = open("memusage.log", "w") if "--log" in sys.argv else None
while True:
	with open("/proc/meminfo") as mem:
		for line in mem:
			key, val = line.split(":")
			if key == "MemAvailable":
				memavail = int(val.replace("kB", ""))
				if log: print(int(time.time()), memavail, file=log)
				if memavail < last:
					print(line.strip())
					last = memavail
				break
	time.sleep(1)
