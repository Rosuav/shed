"""
Tidy up OBS config files

Run this (ideally when OBS isn't running) to tidy up your config files
and make them more consistent. This makes them easier to git-manage or
compare for changes.
"""
import json
import os

# TODO: Where is this on Windows? Mac OS?
CONFIG_PATH = os.path.expanduser("~/.config/obs-studio")

def tidy_file(fn):
	"""Tidy up one file"""
	with open(fn) as f:
		data = json.load(f)
	try: sources = data["sources"]
	except KeyError: pass
	else:
		# If we have an OBS scene config, clean up the 'source'
		# array so we don't get noisy diffs. For some reason it
		# uses an array of dicts (instead of, say, mapping name
		# to all the rest of the info) - and then shuffles them
		# around all the time.
		sources.sort(key=lambda obj: obj["name"])
		# Reset to a default starting scene. This maintains the
		# consistency and, perhaps more importantly, eliminates
		# spurious diffs.
		scenenames = [s["name"] for s in data["scene_order"]]
		# TODO: Look up data["name"] in a local/per-user config
		# file to find the appropriate scene name
		default_scene = "Starting soon"
		if default_scene in scenenames:
			data["current_program_scene"] = data["current_scene"] = default_scene
		# As of 20190520, OBS insists on saving the projectors,
		# even though I clearly said not to. So let's wipe that
		# part of the config too.
		data["saved_projectors"] = []
	# And write the data out tidily, with consistent indent.
	with open(fn, "w") as f:
		json.dump(data, f, indent=4, sort_keys=True)

if __name__ == "__main__":
	for ent in os.scandir(CONFIG_PATH + "/basic/scenes"):
		if ent.is_file() and ent.name.casefold().endswith(".json"):
			tidy_file(ent)
