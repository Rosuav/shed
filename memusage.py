import time
last = float("inf")
while True:
	with open("/proc/meminfo") as mem:
		for line in mem:
			key, val = line.split(":")
			if key == "MemAvailable":
				memavail = int(val.replace("kB", ""))
				if memavail < last:
					print(line.strip())
					last = memavail
				break
	time.sleep(1)
