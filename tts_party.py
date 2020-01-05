#!/usr/bin/python3
# NOTE: May require the system Python 3 rather than using 3.9
import sys
from itertools import count
from io import BytesIO
import time
import speech_recognition as sr
from espeakng import ESpeakNG

text = " ".join(arg for arg in sys.argv[1:] if not arg.startswith("-"))
espeak = ESpeakNG(volume=25)
seen = {}
r = sr.Recognizer()
for seq in count():
	if text in seen: break
	seen[text] = seq
	print("%3d: %s" % (seq, text))
	espeak.say(text)
	spoken = espeak.synth_wav(text)
	with sr.AudioFile(BytesIO(spoken)) as source:
		audio = r.record(source)
		# text = r.recognize_sphinx(audio)
		text = r.recognize_google(audio)
	time.sleep(1)
loop = seq - seen[text]
if loop == 1: print("Achieved stability.")
else: print("Achieved loop of", seq - seen[text], "steps.")
