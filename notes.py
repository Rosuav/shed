#!/usr/bin/python3
# NOTE: May require the system Python 3 rather than using 3.9
import os.path
import sys
import speech_recognition as sr

force_new_block = "--new-block" in sys.argv
desc = " ".join(arg for arg in sys.argv[1:] if not arg.startswith("-"))
if "--gsi" in sys.argv:
	# Call on the GSI server to find out if we're in a CS:GO match, and
	# if so, what we should use as our description
	import requests
	desc = requests.get("http://localhost:27013/status").text
	if desc == "n/a":
		# We're not playing. When running under GSI control (ie NOT
		# explicitly called upon by the terminal), ignore these times.
		sys.exit(0)
	if desc.startswith("--new-block "):
		desc = desc[12:] # == len(the above)
		force_new_block = True

NOTES_DIR = os.path.expanduser(os.environ.get("NOTES_DIR", "~/tmp/notes"))
os.makedirs(NOTES_DIR, exist_ok=True)
blocks = sorted(fn for fn in os.listdir(NOTES_DIR) if fn != "notes.log")

if not blocks or force_new_block:
	next = int(blocks[-1] if blocks else 0) + 1
	blocks.append(str(next))
	os.mkdir(NOTES_DIR + "/" + blocks[-1])
block = NOTES_DIR + "/" + blocks[-1] # Use the latest block (which we may have just created)

notes = os.listdir(block)
notes.sort()
note_id = int(notes[-1].split("-")[0]) + 1 if notes else 1

r = sr.Recognizer()
# Can I increase the gain at all?
with sr.Microphone() as source:
	print("Listening for notes...")
	audio = r.listen(source)#, snowboy_configuration=(
	#	"/home/rosuav/voice-tinkering/snowboy/examples/Python3",
	#	["/home/rosuav/voice-tinkering/snowboy/resources/models/snowboy.umdl"]
	#))
print("Got notes.")

fn = "%02d - " % note_id + desc
with open(block + "/%s.flac" % fn, "wb") as f: f.write(audio.get_flac_data())

try: sphinx = r.recognize_sphinx(audio)
except sr.UnknownValueError: sphinx = ""
except sr.RequestError as e: sphinx = repr(e)

# Maybe TODO: Set an API key with key="...."
try: google = r.recognize_google(audio)
except sr.UnknownValueError: google = ""
except sr.RequestError as e: google = repr(e)

with open(NOTES_DIR + "/notes.log", "a") as f:
	print("[%s]" % block, fn, file=f)
	print("Sphinx:", sphinx, file=f)
	print("Google:", google, file=f)
