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


Public paint pots starts out with {"Beige": STANDARD_BASE}
Personal paint pots starts out empty for all players.
During paint mixing phase, all players may take any base colour (public or personal paint) and add any
pigments, and can save the current paint to personal collection, optionally with a label.
Players get one opportunity to post one of their pots in public. All players see it with the name of the
one who posted it. All players may use it as a base.
Optional: To avoid too much information leakage through timings, players must explicitly check for public pots?
Otherwise, push 'em out on websocket.
When paint mixing phase ends, all players retain access to their personal collections. All players may then
select one paint colour to post a message with. Once all players have done so, the message board is revealed.
Success is defined as your contact correctly selecting your message out of all the messages on the board.


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

Current algorithm uses fractions out of 256, then takes the fourth root. It may be worth rationalizing these
to some nearby approximation, and then differentiating between the "label colour" (the original) and the
"mixing colour" (the three rationals). This will allow efficient and 100% reproducible colour creation. Do not
reveal the actual rational numbers that form the resultant colour, as factors may leak information, but it would
be possible to retain them in that form internally.

(Note that real DHKE uses modulo arithmetic to keep storage requirements sane, so it doesn't have to worry about
rounding or inaccuracies.)
"""
STANDARD_BASE = 0xF5, 0xF5, 0xDC

def _mix_part(base, modifier):
	effect = 1 - (1 - (modifier / 256)) / 5
	return base * effect
def mix(base, modifier):
	return tuple(_mix_part(b, m) for b, m in zip(base, modifier))
def hexcolor(color):
	return "%02X%02X%02X" % tuple(min(int(c + 0.5), 255) for c in color)

PIGMENTS = {
	# Primary colors
	"Crimson": (0xDC, 0x14, 0x3C), # Red
	"Jade": (0x37, 0xFD, 0x12), # Green
	"Cobalt": (0x1F, 0x45, 0xFC), # Blue
	# Secondary colors
	"Hot Pink": (0xFF, 0x14, 0x93), # Rb
	"Orange": (0xFF, 0x8C, 0x0A), # Rg
	"Lawn Green": (0x9C, 0xFC, 0x0D), # Gr
	"Spring Green": (0x03, 0xFA, 0x9A), # Gb
	"Sky Blue": (0x57, 0xCE, 0xFA), # Bg
	"Orchid": (0xDA, 0x40, 0xE6), # Br
	# Special colors, not part of the primary/secondary pattern
	"Rebecca Purple": (0x66, 0x33, 0x99),
	"Chocolate": (0x7B, 0x3F, 0x11),
	"Alice Blue": (0xF0, 0xF8, 0xFE),
	"Mint Mus": (0x99, 0xFD, 0x97),
	"Bulker": tuple(x*2 for x in STANDARD_BASE), # Special-case this one and don't show swatches.
	"Charcoal": (0x44, 0x45, 0x4f),
	"Beige": STANDARD_BASE,
	# Special-case this one. Swatch it as a vibrant crimson (fresh blood), but use the actual "Blood" value for mixing (old blood).
	"Blood-fresh": (0xAA, 0, 0),
	"Blood": (0x7E, 0x35, 0x17),
}
PIGMENT_DESCRIPTIONS = {
	"Crimson": "It's red. What did you expect?",
	"Jade": "Derived from pulverised ancient artifacts. Probably not cursed.",
	"Cobalt": "Like balt, but the other way around",
	"Hot Pink": "Use it quickly before it cools down!",
	"Orange": "For when security absolutely depends on not being able to rhyme",
	"Lawn Green": "Not to be confused with Australian Lawn Green, which is brown",
	"Spring Green": "It's a lie; most of my springs are unpainted",
	"Sky Blue": "Paint your ceiling in this colour and pretend you're outside!",
	"Orchid": "And Kid didn't want to participate, so I got his brother instead",
	"Rebecca Purple": "A tribute to Eric Meyer's daughter. #663399",
	"Chocolate": "Everything's better with chocolate.",
	"Alice Blue": "Who is more famous - the president or his wife?",
	"Mint Mus": "Definitely not a frozen dessert.",
	"Bulker": "Add some more base colour to pale out your paint",
	"Charcoal": "Dirty grey for when vibrant colours just aren't your thing",
	"Beige": "In case the default beige just isn't beigey enough for you",
	"Blood": "This pigment is made from real blood. Use it wisely.",
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
	"Connect to 203.0.113.34 on port 80.",
	"Proceed to the {codename} theatre in the Arts Centre. At the box office, {action}.", # TODO: Abbreviate (too long, esp w/ action)
	"At the stone circle, find the {codename} and read its inscription.",
	"Tell {codename} the dancing stones are restless. They will give you a van.",
	"Go to Teufort. Find {codename} in RED sewers and {action}.",
	"Meet me in the coffee shop. I will be wearing a {codename} T-shirt.",
	"In a garden full of posies, gather flowers. You will be offered an apple. Refuse it.",
	"Tune in to the classical music station. DJ {codename} will instruct you.",
	"Buy a Mars Bar and eat it on Venus.",
	"Borrow Mr {codename}'s camera. If it takes more than one shot, it wasn't a Jakobs.",
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

KEY1 = [("Lawn Green", 3), ("Hot Pink", 1), ("Alice Blue", 3), ("Crimson", 1), ("Orchid", 3)]
KEY2 = [("Orchid", 2), ("Cobalt", 3), ("Bulker", 3), ("Chocolate", 1), ("Rebecca Purple", 1)]
patterns = {
	"Foo": [("Crimson", 3), ("Jade", 1)],
	"Bar": [("Jade", 1), ("Crimson", 3)],
	"Fum": [("Crimson", 2), ("Jade", 1), ("Crimson", 1)],
	"Spam": [*KEY1, *KEY2],
	"Ham": [*KEY2, *KEY1],
}
with open("../tmp/mixing.html", "w") as f:
	print("<!doctype html><html><body>", file=f)
	print("<style>", file=f)
	print(".swatch {display: inline-block; width: 200px; height: 150px; border: 1px solid black;}", file=f)
	print(".small {width: 160px; height: 120px;}", file=f)
	print(".label {display: inline-block; height: 120px;}", file=f)
	print(".base {background: #%s;}" % hexcolor(STANDARD_BASE), file=f)
	print(".design {display: flex; margin: 8px 0; gap: 5px;}", file=f)
	swatches = []
	for name, modifier in PIGMENTS.items():
		name = name.replace(" ", "")
		color = STANDARD_BASE
		swatches.append('<div class=design>')
		swatches.append('<div class="swatch base">Base</div>')
		print(".%s {background: #%s;}" % (name, hexcolor(modifier)), file=f)
		for strength in STRENGTHS:
			color = mix(color, modifier)
			# print("%s (%s): %s" % (name, strength, hexcolor(color)))
			swatches.append('<div class="swatch %s-%s">%s-%s</div>' % (name, strength, name, strength))
			print(".%s-%s {background: #%s;}" % (name, strength, hexcolor(color)), file=f)
		swatches.append('<div class="swatch %s">%s</div>' % (name, name))
		swatches.append('</div>')
	for name, sequence in patterns.items():
		color = STANDARD_BASE
		swatches.append('<div class=design>')
		swatches.append('<div class="swatch small base">Base</div>')
		for i, (pigment, strength) in enumerate(sequence, 1):
			for _ in range(strength):
				color = mix(color, PIGMENTS[pigment])
			swatches.append('<div class="swatch small %s-%d">%s-%s</div>' % (name, i, pigment, STRENGTHS[strength - 1]))
			print(".%s-%d {background: #%s;}" % (name, i, hexcolor(color)), file=f)
		print(".%s {background: #%s;}" % (name, hexcolor(color)), file=f)
		swatches.append('<div class="label">==&gt; %s:<br>%s</div>' % (name, hexcolor(color)))
		swatches.append('</div>')
	print("</style>", file=f)
	print("\n".join(swatches), file=f)
	print("</body></html>", file=f)
