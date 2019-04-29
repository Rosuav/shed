import itertools
import json
import os
import socket
from flask import Flask, request # ImportError? Try "pip install flask".
app = Flask(__name__)

handler = object() # Dict key cookie

composite_file = os.path.dirname(os.readlink(__file__)) + "/composite.json"
composite = {}
try:
	with open(composite_file) as f:
		composite = json.load(f)
except OSError: pass
composite_dirty = False

pw = os.environ.get("VLC_TELNET_PASSWORD") # If not available, VLC management won't be done
def toggle_music(state):
	try:
		sock = socket.create_connection(("127.0.0.1", 4212))
	except OSError: # Most likely ConnectionRefusedError (ie VLC isn't using the telnet interface)
		return # No VLC to manage
	sock.send("{}\n{}\nquit\n".format(pw, state).encode("ascii"))
	data = b""
	while b"Bye-bye!" not in data:
		cur = sock.recv(1024)
		if not cur: break
		data += cur
	sock.close()

configs = {
	# Becomes gsi_player_team.cfg
	("player", "team"): {
		"T": "buy ak47",
		...: "buy aug",
	},
	("map", "mode"): {
		"casual": "buy hegrenade; buy flashbang; buy molotov",
		"competitive": "buy hegrenade; buy flashbang; buy smokegrenade; buy molotov",
	},
	("map", "phase"): {
		# "warmup": "frame", # Optionally pause as soon as warmup starts
		"live": "frame", # Since "pause" toggles pause, we use "frame", which is idempotent.
		"gameover": "frame", # Stay paused until you actually leave the game
		...: "play",
		handler: pw and toggle_music
	},
}

# Some GSI elements function as arrays, even if they're implemented as
# dicts. Their keys are relatively unimportant, and their values are all
# of the same type.
arrays = {
	"data['allplayers']",
	"data['player']['weapons']",
	"data['allplayers']['*']['weapons']",
	"data['grenades']",
	"data['grenades']['*']['flames']",
	"data['map']['round_wins']",
}
def check_composite(data, alldata, path):
	# Check to see if we have any keys not previously seen
	if type(data) is list:
		logging.log(27, "FOUND A LIST! %s[%r]", path, key)
		items = zip(itertools.repeat('*'), data)
	elif path in arrays:
		items = zip(itertools.repeat('*'), data.values())
	else: items = data.items()
	for key, val in items:
		t1 = type(val)
		t2 = type(alldata[key]) if key in alldata else None
		if t1 is int: t1 = float # Use a single "Number" type as per JSON
		if t2 is int: t2 = float
		p = "%s[%r]" % (path, key)
		if t1 is not t2:
			if t2: logging.log(26, "Type conflict on %s: was %s, now %s", p, t2.__name__, t1.__name__)
			else: logging.log(25, "New item -- %s (%s)", p, t1.__name__)
			if t1 in (list, dict): alldata[key] = {}
			else: alldata[key] = val
			global composite_dirty; composite_dirty = True
		# For some types, recurse.
		if t1 in (list, dict):
			check_composite(val, alldata[key], p)

last_known_cfg = {} # Mainly for the sake of logging
@app.route("/", methods=["POST"])
def update_configs():
	if not request.json: return "", 400
	if "previously" in request.json: del request.json["previously"]
	if "added" in request.json: del request.json["added"]
	# from pprint import pprint; pprint(request.json)
	check_composite(request.json, composite, "data")
	global composite_dirty
	if composite_dirty:
		with open(composite_file, "w") as f:
			json.dump(composite, f, indent="\t")
		composite_dirty = False
	# print(request.json.get('player', {}).get('weapons'))
	for path, options in configs.items():
		data = request.json
		# If any part of the path isn't found, data will be None
		for key in path: data = data and data.get(key)
		if data == last_known_cfg.get(path): continue
		last_known_cfg[path] = data
		logging.log(24, "New value for %s: %s", "-".join(path), data)
		cfg = options.get(data, options.get(..., ""))
		filename = "gsi_" + "_".join(path) + ".cfg"
		# We read from the filesystem every time. The last_known_cfg
		# cache will show changes that don't affect the actual state,
		# but those should not trigger the other handlers.
		try:
			with open(filename) as f: prevcfg = f.read()
		except FileNotFoundError:
			prevcfg = ""
		if cfg != prevcfg:
			logging.log(25, "Updating %s => %s", filename, data)
			with open(filename, "w") as f:
				f.write(cfg)
			func = options.get(handler)
			if func: func(cfg)
	return "" # Response doesn't matter

if __name__ == "__main__":
	import logging
	logging.basicConfig(level=24) # use logging.INFO to see timestamped lines every request
	import os; logging.log(25, "I am %d / %d", os.getuid(), os.getgid())
	app.run(host="127.0.0.1", port=27014)
