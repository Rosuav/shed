import os
import socket
from flask import Flask, request # ImportError? Try "pip install flask".
app = Flask(__name__)

handler = object() # Dict key cookie

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

last_known_cfg = {} # Mainly for the sake of logging
@app.route("/", methods=["POST"])
def update_configs():
	if not request.json: return "", 400
	# from pprint import pprint; pprint(request.json)
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
