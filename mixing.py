"""Pseudo-game concept.

I'm writing this up as if it's a game to be played, but the purpose isn't primarily to be a fun game,
it's to be a demonstration. The principles on which this works are the same as the principles which
underpin a lot of internet security, and I'm hoping this can be a fun visualization.

Scenario:
Coded messages are no longer safe. Your enemies have discovered your code, and can both read your messages
and write fake messages of your own. You need a way to send your contact one crucial instruction which will
allow you to share a new code. How? There is a public message board on which anyone may leave a note, so
you must leave a message there, with some proof that it is truly from you.

The Diffie Hellman Paint Company has a public mixing facility. Starting with an ugly beige, you can add
any pigments you like, selected from seventeen options (various secondary or tertiary colours), in any of
three strengths (a spot, a spoonful, or a splash).

You can leave a paint pot (with your name on it and the colour daubed on the label) at the mixer; your
contact will see it, but so will everyone else.

Notes on the board can have painted mastheads. It's easy to compare masthead colours to any pot you
have - "identical", "similar", "different".

With zero private communication, communicate safely.

The trick to it is: Choose *and remember* any combination of pigments. Mix this and leave it under your
name. Your contact does likewise. Then you pick up your contact's paint pot, and mix in the same pigments
that you put into your own; contact does likewise with yours. You are now in possession of identically
coloured pots of paint (which you will not share), and can use them to communicate reliably.


Crucial: Paint mixing. Every paint pot is identified on the server by a unique ID that is *not* defined
by its composition. When you attempt a mix, you get back a new paint pot, and you (but only you) can see
that it's "this base plus these pigments". Everyone else just sees the new ID (if you share it).
Any existing paint pot can be used as a base, or you can use the standard beige base any time.

Essential: Find a mathematical operation which takes a base and a modifier.
* Must be transitive: f(f(b, m1), m2) == f(f(b, m2), m1)
* Must be repeatable: f(f(b, m1), m1) != f(b, m1) up to 3-6 times (it's okay if x*5 and x*6 are visually similar)
* Must "feel" like it's becoming more like that colour (subjective)
* Must not overly darken the result.
The current algorithm works, but probably won't scale to 3-5 pigments without going ugly brown.
Ideally I would like each key to be able to be 3-5 pigments at 1-3 strength each, totalling anywhere from
6 to 30 pigment additions. Maybe add a little bit to the colour each time it's modified, to compensate
for the darkening effect of the pigmentation?

Note: If both sides choose 3-5 pigments at random, and strengths 1-3 each, this gives about 41 bits of key length.
Not a lot by computing standards, but 3e12 possibilities isn't bad for a (pseudo-)game.
"""
STANDARD_BASE = 0xF5, 0xF5, 0xDC

def _mix_part(base, modifier):
	effect = modifier / 256
	return base * (effect ** 0.25)
def mix(base, modifier):
	return tuple(_mix_part(b, m) for b, m in zip(base, modifier))
def hexcolor(color):
	return "%02X%02X%02X" % tuple(int(c + 0.5) for c in color)

PIGMENTS = {
	"Crimson": (0xDC, 0x14, 0x3C),
	"Jade": (0x37, 0xFD, 0x12),
	"Orchid": (0x1F, 0x45, 0xFC),
	"Orange": (0xFF, 0x8C, 0x0A), # Rg
	"Hot Pink": (0xFF, 0x14, 0x93), # Rb
	"Lawn Green": (0x9C, 0xFC, 0x0D), # Gr
	"Spring Green": (0x03, 0xFA, 0x9A), # Gb
	"Orchid": (0xDA, 0x40, 0xE6), # Br
	"Sky Blue": (0x57, 0xCE, 0xFA), # Bg
	# Special colors, not part of the primary/secondary pattern
	"Rebecca Purple": (0x66, 0x33, 0x99),
	"Chocolate": (0x7B, 0x3F, 0x11),
	"Alice Blue": (0xF0, 0xF8, 0xFE),
}
STRENGTHS = "spot", "spoonful", "splash"

# Craft some spy-speak instructions. The game is not about hiding information in the
# text, so we provide the text as a fully-randomized Mad Libs system.
CODENAMES = """Angel Ape Archer Badger Bat Bear Bird Boar Camel Caribou Cat Chimera Cleric Crab Crocodile
Dinosaur Dog Dragon Druid Dwarf Elephant Elk Ferret Fish Fox Frog Giant Goblin Griffin Hamster Hippo
Horse Hyena Insect Jellyfish Knight Kraken Leech Lizard Minotaur Mole Monkey Mouse Ninja Octopus Ogre
Oyster Pangolin Phoenix Pirate Plant Prism Rabbit Ranger Rat Rhino Rogue Salamander Scarecrow Scorpion
Shark Sheep Skeleton Snake Soldier Sphinx Spider Spirit Squirrel Turtle Unicorn Werewolf Whale Worm Yeti
""".split()
ACTIONS = [
	"proceed as planned",
	"ask what the time in London is",
	"complain that the record was scratched",
	"report the theft of your passport",
	"knock six thousand times",
	"whistle the Blue Danube Waltz",
	"wave your sword like a feather duster",
	"apply for the job",
	"enter the code 7355608",
	"take the red pill",
	"dance",
	"sit down",
	"roll for initiative",
]
MESSAGES = [
	"Go to {codename} Office and {action}.",
	"Speak with Agent {codename} for further instructions.",
	"At 11:23 precisely, knock fifty-eight times on Mr Fibonacci's door.",
	"Return to HQ at once.",
	"Mrs {codename}'s bakery serves the best beef and onion pies in the city.",
	"Under the clocks, speak with Authorized Officer {codename}.",
	"When daylight is fading, softly serenade Agent {codename}.",
	"Ride the elevator to the 51st floor and {action}. Beware of vertigo.",
	"Join Agent {codename} in Discord. After five minutes, {action}.",
	"Locate the nearest fire station and {action}.",
	"Connect to 93.184.216.34 on port 80.",
	"Proceed to the {codename} theatre in the Arts Centre. At the box office, {action}.",
	"At the stone circle, find the {codename} and read its inscription.",
	"Tell {codename} the dancing stones are restless. They will give you a van.",
	"Join a TF2 game on 2Fort. Find {codename} in RED sewers and {action}.",
	"Meet me in the coffee shop. I will be wearing a {codename} T-shirt.",
]
MESSAGES.extend([m for m in MESSAGES if m.count("{") > 1]) # Increase the weight of those with multiple placeholders.

_messages_used = { }
def devise_message():
	from random import choice
	while "avoid duplication":
		msg = choice(MESSAGES).format(codename=choice(CODENAMES), action=choice(ACTIONS))
		if msg not in _messages_used: break
	_messages_used[msg] = 1 # Ultimately, use this to record whether it's your secret message or not
	return msg

for _ in range(20): print(devise_message())

patterns = {
	"Foo": [("Crimson", 3), ("Jade", 1)],
	"Bar": [("Jade", 1), ("Crimson", 3)],
	"Fum": [("Crimson", 2), ("Jade", 1), ("Crimson", 1)],
	"Spam": [("Lawn Green", 3), ("Hot Pink", 1), ("Orchid", 2), ("Spring Green", 1)],
	"Ham": [("Orchid", 2), ("Spring Green", 1), ("Lawn Green", 3), ("Hot Pink", 1)],
}
with open("../tmp/mixing.html", "w") as f:
	print("<style>", file=f)
	print(".swatch {display: inline-block; width: 200px; height: 150px; border: 1px solid black;}", file=f)
	print(".base {background: #%s;}" % hexcolor(STANDARD_BASE), file=f)
	swatches = []
	for name, modifier in PIGMENTS.items():
		name = name.replace(" ", "")
		color = STANDARD_BASE
		swatches.append('<p>')
		swatches.append('<div class="swatch base">Base</div>')
		print(".%s {background: #%s;}" % (name, hexcolor(modifier)), file=f)
		for strength in STRENGTHS:
			color = mix(color, modifier)
			# print("%s (%s): %s" % (name, strength, hexcolor(color)))
			swatches.append('<div class="swatch %s-%s">%s-%s</div>' % (name, strength, name, strength))
			print(".%s-%s {background: #%s;}" % (name, strength, hexcolor(color)), file=f)
		swatches.append('<div class="swatch %s">%s</div>' % (name, name))
		swatches.append('</p>')
	for name, sequence in patterns.items():
		color = STANDARD_BASE
		swatches.append('<p>')
		swatches.append('<div class="swatch base">Base</div>')
		for i, (pigment, strength) in enumerate(sequence, 1):
			for _ in range(strength):
				color = mix(color, PIGMENTS[pigment])
			swatches.append('<div class="swatch %s-%d">%s-%s</div>' % (name, i, pigment, STRENGTHS[strength - 1]))
			print(".%s-%d {background: #%s;}" % (name, i, hexcolor(color)), file=f)
		print(".%s {background: #%s;}" % (name, hexcolor(color)), file=f)
		swatches.append('==&gt; %s: %s' % (name, hexcolor(color)))
		swatches.append('</p>')
	print("</style>", file=f)
	print("\n".join(swatches), file=f)
