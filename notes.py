#!/usr/bin/python3
# NOTE: May require the system Python 3 rather than using 3.9
import os.path
import sys
import json
import socket
import requests
import speech_recognition as sr

TRIGGER_SOCKET = "/tmp/stenographer"

"""
TODO:
* Have an ongoing process that holds the microphone device open
* Signal it. Worst case, listen on a Unix socket, and have something open it.
* Record notes, then go back to the loop. This will prevent multiple concurrent notesings though.
* May need a timeout, eg max 30 seconds of notes (to prevent it getting stuck)
* Alternatively, thread them all off. Can they share the microphone??
"""

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

recog = None
def take_notes(*, desc, new_match=False, **extra):
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
	except (IndexError, ValueError): new_match = 2
	if new_match:
		next = int(blocks[-1] if new_match != 2 else 0) + 1
		blocks.append(str(next))
		os.mkdir(NOTES_DIR + "/" + blocks[-1])
	block = NOTES_DIR + "/" + blocks[-1] # Use the latest block (which we may have just created)

	notes = sorted(fn for fn in os.listdir(block) if fn[0] in "0123456789")
	note_id = int(notes[-1].split("-")[0]) + 1 if notes else 1

	global recog
	if recog is None:
		silence_pyaudio()
		recog = sr.Recognizer()

	# Can I increase the gain at all?
	with sr.Microphone() as source:
		print("Listening for notes...")
		audio = recog.listen(source)

	# Discard crazily-long entries. They seem to happen if the recognizer doesn't
	# get a proper silence to start with or something, and it just records forever.
	if len(audio.frame_data) / audio.sample_width / audio.sample_rate > 60.0:
		# More than sixty seconds? Throw it away.
		sys.exit(0)

	print("Got notes.")
	log = open(NOTES_DIR + "/notes.log", "a")
	if new_match:
		print("-" * 65, file=log)
		print("http://localhost:27013/static/notes.html#" + blocks[-1], file=log)
		import webbrowser; webbrowser.open("http://localhost:27013/static/notes.html#" + blocks[-1])

	fn = "%02d - " % note_id + desc
	print("[%s]" % block, fn, file=log, flush=True)
	with open(block + "/%s.flac" % fn, "wb") as f: f.write(audio.get_flac_data())

	d = None
	try: d = recog.recognize_sphinx(audio, show_all=True)
	except sr.UnknownValueError: pass
	except sr.RequestError as e: print("Sphinx:", e, file=log, flush=True)

	options = [b.hypstr for b in d.nbest()] if d else []
	seen = {}
	for txt in options[:5]:
		print("Sphinx: %s" % txt, file=log, flush=True)
		seen[txt] = 1

	# Maybe TODO: Set an API key with key="...."
	try: google = recog.recognize_google(audio)
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
		if key in extra: meta["recordings"][-1][key] = extra[key]
	with open(block + "/metadata.json", "w") as f:
		json.dump(meta, f, sort_keys=True, indent=2)

	if "--gsi" in sys.argv:
		# Signal the GSI server to load new metadata, if appropriate
		requests.post("http://localhost:27013/metadata/" + blocks[-1], json=meta)

if "--gsi" in sys.argv:
	# Try to connect to the trigger socket. If it fails, start the server.
	# Note that this can get into a race situation. I don't know how to
	# perfectly solve this, so we just retry a few times.
	for _ in range(4):
		client = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
		try: client.sendto(b"*", TRIGGER_SOCKET)
		except FileNotFoundError: pass # Socket doesn't exist
		except ConnectionRefusedError: os.unlink(TRIGGER_SOCKET) # Socket exists in the file system but isn't listened on
		else: print("Triggered server"); break # Done! The server's been triggered.

		server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
		try:
			server.bind(TRIGGER_SOCKET)
			print("Listening")
			while True:
				# Do one note-taking now, and then wait for the socket
				gsi_data = requests.get("http://localhost:27013/status.json").json()
				if gsi_data["playing"]:
					take_notes(**gsi_data)
				# TODO: If it's been ten minutes since the last request *and* if GSI
				# says we're not playing, shut down.
				server.recvfrom(1024)
				print("Got trigger")
		except OSError as e:
			if e.errno == 98: continue # Address already in use - try reconnecting
			else: raise
		finally:
			server.close()
			try: os.unlink(TRIGGER_SOCKET)
			except FileNotFoundError: pass
else:
	desc = " ".join(arg for arg in sys.argv[1:] if not arg.startswith("-"))
	take_notes(desc=desc, new_match="--new-block" in sys.argv)
