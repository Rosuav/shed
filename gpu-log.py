# Log GPU stats for subsequent analysis
# Creates/appends to a jsonlines file gpu-log.json
# Each entry has:
	# timestamp: time.time()
	# vram: Percentage of VRAM in use
	# power: Percentage of power limit (wattage) currently being drawn
	# gpu-util: GPU utilization percentage
	# vram-util: VRAM utilization percentage
	# processes: Array of process stats from nVidia's pmon utility:
		# pid: Temporally-unique identifier
		# command: Process name
		# type: "G" if using graphics, "C" if using computation
		# sm, mem, enc, dec: percentages
	# in-cs-match: True if in a CS:GO match, False if not. Not 100% reliable but will work in competitive.
	# cs-status: Textual description of the status of a CS:GO match. Meaningful only if in-cs-match.
# Keeps closing the file after each log entry is written

import json
import subprocess
import time
import requests

def number(s):
	if "." in s: return float(s)
	return int(s)

def log_stats():
	entry = {"timestamp": int(time.time())}

	# Overall usage stats
	fields = "memory.used memory.total utilization.gpu utilization.memory power.draw power.limit".split()
	out = subprocess.run(["nvidia-smi", "--query-gpu=" + ",".join(fields), "--format=csv,nounits,noheader"],
		check=True, capture_output=True, encoding="UTF-8").stdout
	stats = dict(zip(fields, [number(x) for x in out.split(",")]))
	entry["vram"] = int(100 * stats["memory.used"] / stats["memory.total"])
	entry["power"] = int(100 * stats["power.draw"] / stats["power.limit"])
	entry["gpu-util"] = stats["utilization.gpu"]
	entry["vram-util"] = stats["utilization.memory"]

	# Per-process stats
	lines = subprocess.run(["nvidia-smi", "pmon", "-s", "um", "-c", "1"],
		check=True, capture_output=True, encoding="UTF-8").stdout.split("\n")
	lines = [line.strip("# ").split(maxsplit=8) for line in lines if line]
	fields = lines[0]
	# units = lines[1]
	entry["processes"] = [dict(zip(fields, line)) for line in lines[2:]]

	# CS:GO activity indication
	status = requests.get("http://localhost:27013/status.json?silent=true").json()
	entry["in-cs-match"] = status["playing"]
	entry["cs-status"] = status.get("desc", "")

	# Log it!
	with open("gpu-log.json", "a") as f:
		json.dump(entry, f)
		f.write("\n")
	print(f"{entry['vram']:2}% VRAM {entry['vram-util']:2}% util, "
		f"{entry['gpu-util']:2}% GPU, {entry['power']:2}% power "
		f"{entry['cs-status'] if entry['in-cs-match'] else ''}")

if __name__ == "__main__":
	try:
		while True:
			log_stats()
			time.sleep(10)
	except KeyboardInterrupt:
		# Normal exit
		pass
