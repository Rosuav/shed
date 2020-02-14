import collections
import itertools
import json
import sys
import matplotlib.pyplot as plt


"""
Attempting to diagnose a weird problem. The main symptom is that the frame rate in CS:GO plummets,
and VRAM utilization falls to single digits of percent while GPU utilization stays pegged. This
has only ever been noted when Surviving Mars (aka MarsSteam) is also running, but it may or may not
actually be related to that specifically. Closing Mars doesn't solve the problem.

Once the problem has been triggered, it can be poked at by changing graphics settings in CS:GO. This
does not solve the problem but can affect the resultant frame rate. The ONLY way to solve it is to
restart CS:GO, upon which everything is absolutely perfectly clean.

During the problem period, csgo_linux64 has very high "sm" (which seems to correspond to GPU usage),
but other than that, nothing seems particularly odd.
"""

with open("gpu-log.json") as f:
	# Note that this is actually jsonlines, not pure JSON
	data = [json.loads(l) for l in f if l]

MAX_GRAPH_POINTS = 300

example = {
	"timestamp": 1581669334,
	"vram": 65, "power": 25, # Usage percentages
	"gpu-util": 13, "vram-util": 7, # Utilization percentages
	"processes": [
		{"gpu": "0", "pid": "1342", "type": "G", "sm": "0", "mem": "0", "enc": "0", "dec": "0", "fb": "236", "command": "Xorg"},
		{"gpu": "0", "pid": "2311", "type": "G", "sm": "9", "mem": "5", "enc": "0", "dec": "0", "fb": "1993", "command": "csgo_linux64"},
		{"gpu": "0", "pid": "3052", "type": "G", "sm": "0", "mem": "0", "enc": "0", "dec": "0", "fb": "100", "command": "chrome --type=g"},
		{"gpu": "0", "pid": "3682", "type": "G", "sm": "0", "mem": "0", "enc": "0", "dec": "0", "fb": "0", "command": "nvidia-settings"},
		{"gpu": "0", "pid": "7325", "type": "C+G", "sm": "2", "mem": "1", "enc": "0", "dec": "0", "fb": "199", "command": "NGUIdle.exe"},
		{"gpu": "0", "pid": "21594", "type": "G", "sm": "0", "mem": "0", "enc": "0", "dec": "0", "fb": "17", "command": "steam"},
		{"gpu": "0", "pid": "21603", "type": "G", "sm": "0", "mem": "0", "enc": "0", "dec": "0", "fb": "2", "command": "steamwebhelper"},
		{"gpu": "0", "pid": "21617", "type": "G", "sm": "0", "mem": "0", "enc": "0", "dec": "0", "fb": "85", "command": "cef_log.txt --p"}
	],
	"in-cs-match": False, "cs-status": "R0 (--::--) (75.4s)"
}

# Slice based on the timestamps to find the interesting part
data = [d for d in data if 1581666922 <= d["timestamp"] <= 1581668008]
print(len(data), "data points.")

def graph_processes():
	processes = collections.defaultdict(lambda: [0] * len(data))
	processes["All"] # Put it first. It should perfectly track the Total, which comes from the vram figure.
	# Graph proc["fb"] aka "framebuffer usage (MB)" to show VRAM usage
	# Graph proc["sm"] aka "??????? I have no idea what that stands for ??????" to show GPU usage
	for i, entry in enumerate(data):
		for proc in entry["processes"]:
			processes[proc["command"]][i] = int(proc["fb"])
			processes["All"][i] += int(proc["fb"])
	for label, usage in processes.items():
		plt.plot(usage, label=label)
	graph([d["vram"] * 40.96 for d in data], label="Total") # Rescale from percentage to megabytes (I don't have total VRAM in these stats but it's 4096MB for me)
	# graph([d["gpu-util"] for d in data], label="Total") # Or graph total GPU usage
	plt.legend()
	plt.show()

def avg(lst): return sum(lst) // len(lst) # Flooring average. Might give slightly low values.

def graph(data, **kw):
	# Gather the data into no more than MAX_GRAPH_POINTS points
	# Averages groups to get down to that figure.
	if len(data) > MAX_GRAPH_POINTS:
		size = len(data) // MAX_GRAPH_POINTS + bool(len(data) % MAX_GRAPH_POINTS) # round up, crude way, no floats involved
		data = [avg(data[pos : pos + size]) for pos in range(0, len(data), size)]
	plt.plot(data, **kw)

# graph_processes(); sys.exit(0)

graph([d["vram"] for d in data], label="VRAM used")
graph([d["vram-util"] for d in data], label="VRAM active")
graph([d["gpu-util"] for d in data], label="GPU %")
# graph([d["power"] for d in data], label="Wattage")
plt.legend()
plt.show()
