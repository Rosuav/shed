import itertools
import json
import os
import socket
import subprocess
import threading
import tempfile
import re
import requests
from flask import Flask, request # ImportError? Try "pip install flask".
app = Flask(__name__)

handler = object() # Dict key cookie

composite_file = os.path.dirname(os.readlink(__file__)) + "/composite%s.json"
composite, composite_live = {}, {}
try:
	with open(composite_file % "") as f:
		composite = json.load(f)
	with open(composite_file % "_live") as f:
		composite_live = json.load(f)
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

NOTES_DIR = "/home/rosuav/tmp/notes"
last_idle_block = 0
def _fn_order(n):
	"""File name order - integers at start of file name, but ignore nonnumerics"""
	try: return int(n)
	except (ValueError, TypeError): return 0
def get_block_id():
	return max(os.listdir(NOTES_DIR), key=_fn_order, default=0)

def screencap():
	# There'll be 15 seconds (interval) or 25 seconds (game over) of scoreboard.
	# Screencap it (rounding up to 30s for safety) and make an animation.
	# Thus whenever the scoreboard is up, we take a series of screenshots.
	# Find CS:GO window: wmctrl -lG|grep Counter-Strike
	# ffmpeg -video_size 1920x1080 -framerate 3 -f x11grab -i :0.0+1920,0 -c copy scoreboard.mkv
	# Attach these to the last notes. Ideally, take a few frames a second, but play them back slower.
	# TODO: Take notes only if (a) it's competitive, and (b) I'm participating, not spectating.
	try:
		p = subprocess.run(["wmctrl", "-lG"], capture_output=True, check=True)
	except (subprocess.CalledProcessError, FileNotFoundError):
		return
	for line in p.stdout.decode().split("\n"):
		# 0x07200005  2 1920 0    1920 1080 sikorsky Counter-Strike: Global Offensive - OpenGL
		id, desktop, x, y, w, h, user, title = line.split(maxsplit=7)
		if title.startswith("Counter-Strike: Global Offensive"): break
	else:
		# No CS:GO window found; no screencap needed.
		# I'm not sure how this would happen, since this is triggered by GSI,
		# but maybe there's a change to the window title or something.
		return
	last_block = get_block_id()
	if not last_block: return # No notes to attach to
	if last_block <= last_idle_block: return # We've been idle since recording those notes.
	block = NOTES_DIR + "/" + last_block
	tempfd, tempfn = tempfile.mkstemp(suffix=".mkv", dir=block)
	try:
		proc = subprocess.Popen(["ffmpeg", "-y",
			"-loglevel", "quiet",
			"-video_size", w + "x" + h,
			"-framerate", "2",
			"-f", "x11grab", "-i", f"{os.environ['DISPLAY']}+{x},{y}",
			"-t", "40",
			tempfn,
		], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	except FileNotFoundError:
		os.close(tempfd)
		return # No FFMPEG
	logging.log(25, "Screencapping into %s", tempfn)
	def wait():
		proc.wait()
		# Largely duplicated from notes.py
		try:
			with open(block + "/metadata.json") as f: meta = json.load(f)
		except (FileNotFoundError, json.decoder.JSONDecodeError): meta = {}
		if "recordings" not in meta: meta["recordings"] = []
		note_id = meta["recordings"][-1]["id"] + 1 if meta["recordings"] else 1
		fn = f"/{note_id:02d} - screencap.mkv"
		os.rename(tempfn, block + fn)
		os.close(tempfd)
		meta["recordings"].append({
			"id": note_id,
			"filename": fn,
			"type": "video",
		})
		with open(block + "/metadata.json", "w") as f:
			json.dump(meta, f, sort_keys=True, indent=2)

		# Signal the GSI server to load new metadata, if appropriate
		requests.post("http://localhost:27013/metadata/" + last_block, json=meta)
	threading.Thread(target=wait).start()

last_mode = None
def mode_switch(mode):
	if pw: # If we have a VLC password, manage the music
		# Since "pause" toggles pause, we use "frame", which is idempotent.
		toggle_music("play" if mode == "idle" else "frame")

	global last_mode
	if last_mode == mode: return
	last_mode = mode
	logging.log(25, "Setting mode to %s", mode)
	if mode == "screencap":
		# Fire-and-forget the screencapping. Once triggered, this won't untrigger
		# until we've seen something different, so it's unlikely we'll spam the
		# notes collection.
		screencap()

	# Manage whether or not the note taker is listening for a global hotkey
	# NOTE: This autoconfiguration may require env var DBUS_SESSION_BUS_ADDRESS to
	# be appropriately set. It usually will be when running within the GUI, but if
	# this script is run in the background somewhere, be sure to propagate it.
	command = ["xfconf-query", "-c", "xfce4-keyboard-shortcuts", "-p", "/commands/custom/<Alt>d"]
	if mode == "idle":
		subprocess.run(command + ["--reset"])
		global last_idle_block
		last_idle_block = get_block_id()
	else: subprocess.run(command + ["-n", "-t", "string", "-s", "/home/rosuav/shed/notes.py --gsi"])

# NOTE: Money calculation is inactive if player_state is disabled in the config
show_money = False
last_money = 0
def plot_money(state):
	if not show_money or not isinstance(state, int): return
	global last_money
	if state < last_money:
		logging.log(28, "Money: %d (-%d, -%.2f%%)", state,
			last_money - state, 100 * (last_money - state) / (last_money or state))
	last_money = state
def toggle_money(state):
	global show_money
	show_money = state == "Rosuav"
	# logging.log(28, "Watching: %r", state)

def playing_phase(data):
	# If we're spectating, "spec", otherwise the current map phase.
	if "allplayers" in data: return "spec"
	return data.get("map", {}).get("phase", "idle")

def current_round_only_if_spectating(data):
	# Yeah it's a bit weird. Return the current round number IF we are
	# currently spectating a competitive match, otherwise None.
	if "allplayers" in data and data.get("map", {}).get("mode") == "competitive":
		round = int(data.get("map", {}).get("round", 0))
		if data.get("round", {}).get("phase") in ("freezetime", "live"):
			# CS:GO numbers rounds from 0, but we'd prefer to number them from 1.
			# However, when the round is over, CS:GO snaps it to the next number
			# even though we'd rather not call it round N until the start of the
			# freeze time for that round.
			round += 1
		# print("Spectating compet round", round)
		return round
	# print("Not spectating compet")

def update_demo_ticks(round):
	if round is None: return
	try:
		with open("../demoticks.log") as f:
			ticks = []
			for line in f:
				if line.strip() == "Important Ticks in demo:":
					# Start of a new dump. We need to take the very last one.
					# Ideally, the file should be pruned periodically. Or even
					# better, have the F10 key truncate the file before writing
					# the demo info to it, but I don't know how to do that.
					ticks = []
					continue
				# The bomb will never be picked up in warmup. We need a shim at slot 0,
				# for which the warmup round_start event normally suffices; but if that
				# hasn't been seen, slip a zero in there so we can ignore it.
				m = re.match("Tick: ([0-9]+)  Event: bomb_pickup", line)
				if m and not ticks: ticks.append(0)
				m = re.match("Tick: ([0-9]+)  Event: round_start", line)
				if not m: continue
				ticks.append(int(m.group(1)))
			round = int(round)
			# ticks[0] should be the start of warmup
			for name, ofs in (("previous", -1), ("next", +1)):
				r = round + ofs
				with open("gsi_%s_round.cfg" % name, "wt") as cfg:
					if r < len(ticks):
						print('echo "Going to %s round %d (tick %d)"' % (name, r, ticks[r]), file=cfg)
						print("demo_goto", ticks[r], file=cfg)
					else:
						print('echo "No such round %d"' % r, file=cfg)
	except FileNotFoundError:
		pass
	except ValueError as e:
		print("Demotick parse error:", e)
		# Leave the files unchanged

configs = {
	# Becomes gsi_player_team.cfg
	("player", "team"): {
		"T": "buy mac10",
		...: "buy mag7",
		handler: "file"
	},
	("map", "mode"): {
		"casual": "buy hegrenade; buy smokegrenade; buy molotov",
		"competitive": "buy hegrenade; buy smokegrenade; buy flashbang; buy molotov",
		handler: "file"
	},
	playing_phase: {
		"warmup": "playing",
		"live": "playing",
		"gameover": "screencap",
		"intermission": "screencap",
		...: "idle",
		handler: mode_switch
	},
	("player", "name"): {...: ..., handler: toggle_money},
	("player", "state", "money"): {...: ..., handler: plot_money},
	current_round_only_if_spectating: {...: ..., handler: update_demo_ticks},
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
		# Detect enumerated types and give some examples of free-form ones
		if t1 is str:
			if val not in alldata[key].split("||") and len(alldata[key] + "||" + val) < 120:
				logging.log(25, "New value for item -- %s (%s)", p, val)
				alldata[key] += "||" + val
				composite_dirty = True

last_known_cfg = {} # Mainly for the sake of logging
@app.route("/", methods=["POST"])
def update_configs():
	if not request.json: return "", 400
	if "previously" in request.json: del request.json["previously"]
	if "added" in request.json: del request.json["added"]
	# from pprint import pprint; pprint(request.json)
	check_composite(request.json, composite, "data")
	if "allplayers" not in request.json and request.json.get("map", {}).get("mode") == "competitive":
		# Track in-match info as well - only that info that we can see while playing
		# Note that this won't necessarily catch EVERYTHING (for instance, I might
		# never happen to spec someone who has a flag set, even though theoretically
		# that might be seen live), but it'd be most of it.
		check_composite(request.json, composite_live, "data")
	global composite_dirty
	if composite_dirty:
		with open(composite_file % "", "w") as f:
			json.dump(composite, f, indent="\t")
		with open(composite_file % "_live", "w") as f:
			json.dump(composite_live, f, indent="\t")
		composite_dirty = False
	# print(request.json.get('player', {}).get('weapons'))
	for path, options in configs.items():
		data = request.json
		if isinstance(path, tuple):
			# If any part of the path isn't found, data will be None
			for key in path: data = data and data.get(key)
		else:
			data = path(data)
		if data == last_known_cfg.get(path): continue
		last_known_cfg[path] = data
		# logging.log(24, "New value for %s: %s", "-".join(path), data)
		cfg = options.get(data, options.get(..., ""))
		if cfg == ...: cfg = data
		func = options.get(handler)
		if func == "file":
			# We read from the filesystem every time. The last_known_cfg
			# cache will show changes that don't affect the actual state,
			# but those should not trigger the other handlers.
			filename = "gsi_" + "_".join(path) + ".cfg"
			try:
				with open(filename) as f: prevcfg = f.read()
			except FileNotFoundError:
				prevcfg = ""
			if cfg != prevcfg:
				logging.log(25, "Updating %s => %s", filename, data)
				with open(filename, "w") as f:
					f.write(str(cfg))
		elif func: func(cfg)
	return "" # Response doesn't matter

if __name__ == "__main__":
	import logging
	logging.basicConfig(level=24) # use logging.INFO to see timestamped lines every request
	logging.getLogger("werkzeug").setLevel(logging.WARNING)
	import os; logging.log(25, "I am %d / %d", os.getuid(), os.getgid())
	app.run(host="127.0.0.1", port=27014)
