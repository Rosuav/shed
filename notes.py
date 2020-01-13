#!/usr/bin/python3
# NOTE: May require the system Python 3 rather than using 3.9
import os.path
import sys
import json
import speech_recognition as sr

new_block = "--new-block" in sys.argv
desc = " ".join(arg for arg in sys.argv[1:] if not arg.startswith("-"))
if "--gsi" in sys.argv:
	# Call on the GSI server to find out if we're in a CS:GO match, and
	# if so, what we should use as our description
	import requests
	gsi_data = requests.get("http://localhost:27013/status.json").json()
	if not gsi_data["playing"]:
		# We're not playing. When running under GSI control (ie NOT
		# explicitly called upon by the terminal), ignore these times.
		sys.exit(0)
	if gsi_data["new_match"]: new_block = 1
	desc = gsi_data["desc"]
else: gsi_data = {}

NOTES_DIR = os.path.expanduser(os.environ.get("NOTES_DIR", "~/tmp/notes"))
os.makedirs(NOTES_DIR, exist_ok=True)

def safe_int(n):
	"""Sort key for probably-numeric strings

	Sorts unparseable strings first in lexicographical order, then
	everything that intifies in numerical order.
	"""
	try: return (1, int(n))
	except (ValueError, TypeError): return (0, n)

blocks = sorted(os.listdir(NOTES_DIR), key=safe_int)

try: int(blocks[-1])
except (IndexError, ValueError): new_block = 2
if new_block:
	next = int(blocks[-1] if new_block != 2 else 0) + 1
	blocks.append(str(next))
	os.mkdir(NOTES_DIR + "/" + blocks[-1])
block = NOTES_DIR + "/" + blocks[-1] # Use the latest block (which we may have just created)

notes = sorted(fn for fn in os.listdir(block) if fn[0] in "0123456789")
note_id = int(notes[-1].split("-")[0]) + 1 if notes else 1

# Get rid of the ALSA warnings by preloading it with stderr muted
def silence_pyaudio():
	devnull = os.open(os.devnull, os.O_WRONLY)
	old_stderr = os.dup(2)
	sys.stderr.flush()
	os.dup2(devnull, 2)
	os.close(devnull)
	try:
		import pyaudio; pyaudio.PyAudio()
	finally:
		os.dup2(old_stderr, 2)
		os.close(old_stderr)
silence_pyaudio()

r = sr.Recognizer()
# Can I increase the gain at all?
with sr.Microphone() as source:
	print("Listening for notes...")
	audio = r.listen(source)#, snowboy_configuration=(
	#	"/home/rosuav/voice-tinkering/snowboy/examples/Python3",
	#	["/home/rosuav/voice-tinkering/snowboy/resources/models/snowboy.umdl"]
	#))
print("Got notes.")
log = open(NOTES_DIR + "/notes.log", "a")
if new_block:
	print("-" * 65, file=log)
	print("http://localhost:27013/static/notes.html#" + blocks[-1], file=log)

fn = "%02d - " % note_id + desc
print("[%s]" % block, fn, file=log, flush=True)
with open(block + "/%s.flac" % fn, "wb") as f: f.write(audio.get_flac_data())

d = None
try: d = r.recognize_sphinx(audio, show_all=True)
except sr.UnknownValueError: pass
except sr.RequestError as e: print("Sphinx:", e, file=log, flush=True)

options = [b.hypstr for b in d.nbest()] if d else []
seen = {}
for txt in options[:5]:
	print("Sphinx: %s" % txt, file=log, flush=True)
	seen[txt] = 1

# Maybe TODO: Set an API key with key="...."
try: google = r.recognize_google(audio)
except sr.UnknownValueError: google = ""
except sr.RequestError as e: google = repr(e)

print("Google:", google, file=log, flush=True)

try:
	with open(block + "/metadata.json") as f: meta = json.load(f)
except (FileNotFoundError, json.decoder.JSONDecodeError): meta = {}
if "recordings" not in meta: meta["recordings"] = []
meta["recordings"].append({
	"id": note_id,
	"desc": desc,
	"filename": "/%s.flac" % fn,
	"sphinx": options[:5],
	"google": google,
})
for key in "round", "spec", "score", "time", "bombtime":
	if key in gsi_data: meta["recordings"][-1][key] = gsi_data[key]
with open(block + "/metadata.json", "w") as f:
	json.dump(meta, f, sort_keys=True, indent=2)

if "--gsi" in sys.argv:
	# Signal the GSI server to load new metadata, if appropriate
	requests.post("http://localhost:27013/metadata/" + blocks[-1], json=meta)

sys.exit(0) # Boosting volume doesn't really seem to help much.

# Attempt to boost the volume and re-transcribe
try: import numpy
except ImportError: sys.exit(0) # No numpy? Whatever, no biggie.
# Assume that the data is signed integers
dtype = {1: numpy.int8, 2: numpy.int16, 4: numpy.int32}[audio.sample_width]
data = numpy.frombuffer(audio.frame_data, dtype=dtype)
for factor in (2, 3, 4): # Going beyond 4 doesn't seem to help much
	audio.frame_data = (data * factor).tobytes()
	try: d = r.recognize_sphinx(audio, show_all=True)
	except (sr.UnknownValueError, sr.RequestError): continue
	for i, txt in enumerate([b.hypstr for b in d.nbest()][:5], 1):
		if txt not in seen:
			print("Sphinx*%d#%d: %s" % (factor, i, txt), file=log, flush=True)
			seen[txt] = factor
