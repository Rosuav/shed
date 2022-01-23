"""Pseudo-game concept.

I'm writing this up as if it's a game to be played, but the purpose isn't primarily to be a fun game,
it's to be a demonstration. The principles on which this works are the same as the principles which
underpin a lot of internet security, and I'm hoping this can be a fun visualization.

Scenario:
There is a public message board on which anyone may leave a note. You need to send a vital message to your
contact, but other people may also leave messages, so your contact needs to be sure which one is from you.

The Diffie Hellman Paint Company has a public mixing facility. Starting with an ugly beige, you can add
any pigments you like, selected from seventeen options (various secondary or tertiary colours), in any of
three strengths (a spot, a spoonful, or a splash).

You can leave a paint pot (with your name on it and the colour daubed on the label) at the mixer; your
contact will see it, but so will everyone else.

Notes on the board can have painted mastheads. It's easy to compare masthead colours to any pot you
have - "identical", "similar", "different".

With zero private communication, communicate safely.


Crucial: Paint mixing. Every paint pot is identified on the server by a unique ID that is *not* defined
by its composition. When you attempt a mix, you get back a new paint pot, and you (but only you) can see
that it's "this base plus these pigments". Everyone else just sees the new ID and label (if you share it).
Any existing paint pot can be used as a base, or you can use the standard beige base any time.

Standard Base: F5F5DC
Pigments:
* Crimson DC143C
* Jade (might need better name) 37FD12
* Orchid 1F45FC
* Need secondary colours and a few others just for the sake of things

Essential: Find a mathematical operation which takes a base and a modifier.
* Must be transitive: f(f(b, m1), m2) == f(f(b, m2), m1)
* Must be repeatable: f(f(b, m1), m1) != f(b, m1) up to (at least) three times
* Must "feel" like it's becoming more like that colour (subjective)
* Must not overly darken the result.
The current algorithm works, but probably won't scale to 3-5 pigments without going ugly brown.
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
}
STRENGTHS = "spot", "spoonful", "splash"
patterns = {
	"Foo": [("Crimson", 3), ("Jade", 1)],
	"Bar": [("Jade", 1), ("Crimson", 3)],
	"Fum": [("Crimson", 2), ("Jade", 1), ("Crimson", 1)],
}
with open("../tmp/mixing.html", "w") as f:
	print("<style>", file=f)
	print(".swatch {display: inline-block; width: 200px; height: 150px; border: 1px solid black;}", file=f)
	print(".base {background: #%s;}" % hexcolor(STANDARD_BASE), file=f)
	swatches = []
	for name, modifier in PIGMENTS.items():
		color = STANDARD_BASE
		swatches.append('<p>')
		swatches.append('<div class="swatch base">Base</div>')
		print(".%s {background: #%s;}" % (name, hexcolor(modifier)), file=f)
		for strength in STRENGTHS:
			color = mix(color, modifier)
			print("%s (%s): %s" % (name, strength, hexcolor(color)))
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
		swatches.append('==&gt; <div class="swatch %s">%s</div>' % (name, name))
		swatches.append('</p>')
	print("</style>", file=f)
	print("\n".join(swatches), file=f)
