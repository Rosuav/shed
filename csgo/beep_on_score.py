# Play audio when stuff happens
import math
import struct
import numpy
import pygame.mixer
FREQ = 44100
pygame.mixer.init(frequency=FREQ, size=-16, channels=1)

AMPLITUDE = 2048

pips = []
def make_pip(pitch, duration):
	samples = [math.sin(2.0 * math.pi * pitch * t / FREQ) for t in range(0, int(duration * FREQ))]
	data = numpy.array([int(s * AMPLITUDE) for s in samples], dtype=numpy.int16)
	sound = pygame.sndarray.make_sound(data)
	pips.append(sound)

make_pip(440, 0.0625) # One point gained
make_pip(523, 0.0625) # Two points gained at once
make_pip(660, 0.125) # Three ditto ditto
make_pip(880, 0.125)
make_pip(1047, 0.125) # The last one gets "and anything higher"

def play_pip(pip):
	if pip < 0: return
	if pip >= len(pips): pip = -1 # Past the end? Take the last one.
	pips[pip].play()

# Stuff happens when you gain score
from pprint import pprint
from flask import Flask, request # ImportError? Try "pip install flask".
app = Flask(__name__)

last_score = {}
@app.route("/", methods=["POST"])
def update_configs():
	if not isinstance(request.json, dict): return "", 400
	if 0: # Dump everything out to the console
		if "previously" in request.json: del request.json["previously"]
		if "added" in request.json: del request.json["added"]
		if request.json: pprint(request.json)
	try:
		score = request.json["player"]["match_stats"]["score"]
		person = request.json["player"]["name"]
	except KeyError: return "" # Probably not in a match
	if person in last_score and score > last_score[person]:
		print(person, "gained", score - last_score[person], "=>", score)
		play_pip(score - last_score[person] - 1)
	last_score[person] = score
	return "" # Response doesn't matter

if __name__ == "__main__":
	import logging; logging.basicConfig(level=24) # use logging.INFO to see timestamped lines every request
	# import os; logging.log(25, "I am %d / %d", os.getuid(), os.getgid())
	app.run(host="127.0.0.1", port=27016)
