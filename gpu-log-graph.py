import json
import matplotlib.pyplot as plt

with open("gpu-log.json") as f:
	# Note that this is actually jsonlines, not pure JSON
	data = [json.loads(l) for l in f if l]

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

plt.plot([d["vram"] for d in data], label="VRAM used")
plt.plot([d["vram-util"] for d in data], label="VRAM active")
plt.plot([d["gpu-util"] for d in data], label="GPU %")
plt.plot([d["power"] for d in data], label="Wattage")
plt.legend()
plt.show()
