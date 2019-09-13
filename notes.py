#!/usr/bin/python3
# NOTE: May require the system Python 3 rather than using 3.9
import speech_recognition as sr
r = sr.Recognizer()
# Can I increase the gain at all?
with sr.Microphone() as source:
	print("Listening for notes...")
	audio = r.listen(source)
	# snowboy_configuration=(
		# "/home/rosuav/snowboy-1.3.0/examples/Python3",
		# ["/home/rosuav/snowboy-1.3.0/resources/models/snowboy.umdl"]
	# )
print("Got notes.")

import random
with open("notes%d.flac" % random.randrange(10000), "wb") as f: f.write(audio.get_flac_data())

try: sphinx = r.recognize_sphinx(audio)
except sr.UnknownValueError: sphinx = ""
except sr.RequestError as e: sphinx = repr(e)

# Maybe TODO: Set an API key with key="...."
try: google = r.recognize_google(audio)
except sr.UnknownValueError: google = ""
except sr.RequestError as e: google = repr(e)

print("Sphinx:", sphinx)
print("Google:", google)
