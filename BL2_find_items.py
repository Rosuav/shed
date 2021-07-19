# Parse Borderlands 2 savefiles and list all items across all characters
# See https://github.com/gibbed/Gibbed.Borderlands2 for a Windows-only
# program to do way more than this, including actually changing stuff.
# This is much simpler; its purpose is to help you twink items between
# your characters, or more specifically, to find the items that you want
# to twink. It should be able to handle Windows and Linux save files, but
# not save files from consoles (they may be big-endian, and/or use another
# compression algorithm). Currently the path is hard-coded for Linux though.
import argparse
import base64
import binascii
import collections
import hashlib
import itertools
import json
import math
import os.path
import struct
import sys
import random
from fnmatch import fnmatch
from dataclasses import dataclass # ImportError? Upgrade to Python 3.7 or pip install dataclasses
from pprint import pprint
import lzo # ImportError? pip install python-lzo (or downgrade to Python 3.9 possibly)
from BL1_find_items import FunctionArg, Consumable

# python-lzo 1.12 on Python 3.8 causes a DeprecationWarning regarding arg parsing with integers.
import warnings; warnings.filterwarnings("ignore")

loot_filter = FunctionArg("filter", 2)

@loot_filter
def level(usage, item, minlvl, maxlvl=None):
	minlvl = int(minlvl)
	if maxlvl is None: maxlvl = minlvl + 5
	return minlvl <= item.grade <= int(maxlvl)

@loot_filter
def type(usage, item, type): return type in item.type
del type # I want the filter to be called type, but not to override type()

@loot_filter
def title(usage, item, tit): return item.title is not None and tit in item.title

@loot_filter
def loose(usage, item): return not usage.is_equipped() and usage.is_carried()

synthesizer = FunctionArg("synth", 1)

def strip_prefix(str): return str.split(".", 1)[1]
def armor_serial(serial): return base64.b64encode(serial).decode("ascii").strip("=")
def unarmor_serial(id): return base64.b64decode(id.strip("{}").encode("ascii") + b"====")
def partnames(is_weapon):
	if is_weapon: return "body grip barrel sight stock elemental accessory1 accessory2".split()
	return "alpha beta gamma delta epsilon zeta eta theta".split()

@synthesizer
def money(savefile): savefile.money[0] += 5000000 # Add more dollars
@synthesizer
def eridium(savefile): savefile.money[1] += 500 # Add more eridium/moonstones
@synthesizer
def seraph(savefile): savefile.money[2] += 500 # Not sure what, if anything, these two would do in TPS
@synthesizer
def torgue(savefile): savefile.money[4] += 500

@synthesizer
def xp(savefile, xp=None):
	# Change the experience point count, without going beyond the level.
	min = math.ceil(60 * savefile.level ** 2.8 - 60)
	max = math.ceil(60 * (savefile.level + 1) ** 2.8 - 60) - 1
	if xp is None: savefile.exp = max
	elif min <= int(xp) <= max: savefile.exp = int(xp)
	else: print("WARNING: Leaving XP unchanged - level %d needs %d-%d XP" % (savefile.level, min, max))

@synthesizer
def boost(savefile):
	"""Boost the levels of all equipped gear lower than your current level"""
	for i, weapon in enumerate(savefile.packed_weapon_data):
		weap = Asset.decode_asset_library(weapon.serial)
		if weap.grade < savefile.level and weapon.quickslot:
			weap.grade = weap.stage = savefile.level
			savefile.packed_weapon_data[i].serial = weap.encode_asset_library()
	for i, item in enumerate(savefile.packed_item_data):
		it = Asset.decode_asset_library(item.serial)
		if it and it.grade < savefile.level and item.equipped:
			it.grade = it.stage = savefile.level
			savefile.packed_item_data[i].serial = it.encode_asset_library()

@synthesizer
def invdup(savefile, level):
	"""Duplicate inventory at a new level for comparison"""
	levels = [int(l) for l in level.split(",") if l]
	if not levels: raise ValueError("C'mon, get on my level, man")
	for weapon in savefile.packed_weapon_data:
		weap = Asset.decode_asset_library(weapon.serial)
		if weap.grade not in levels and not weapon.quickslot:
			for level in levels:
				weap.grade = weap.stage = level
				weap.seed = random.randrange(1<<31)
				savefile.add_inventory(weap)
	for item in savefile.packed_item_data:
		it = Asset.decode_asset_library(item.serial)
		if it and it.grade not in levels and not item.equipped:
			for level in levels:
				it.grade = it.stage = level
				it.seed = random.randrange(1<<31)
				savefile.add_inventory(it)

@synthesizer
def item(savefile, bal):
	"""Synthesize some possible weapon/item based on its Balance definition"""
	# Random note: Glitch attachments that begin with 0 are identified correctly
	# eg GD_Ma_Weapons.Glitch_Attachments.Glitch_Attachment_0421 gives O0L4M2A1.
	# Other attachments have the internal name give an Amplify value higher by one
	# eg GD_Ma_Weapons.Glitch_Attachments.Glitch_Attachment_2144 is O2L1M4A3. Odd.
	try:
		balance = get_balance_info(0, bal)
		is_weapon = 0
	except KeyError:
		balance = get_balance_info(1, bal)
		is_weapon = 1
	if "type" in balance: type = balance["type"]
	else: type = balance["types"][0]
	typeinfo = get_asset("Weapon Types" if is_weapon else "Item Types")[type]
	def p(part):
		b = balance.get(part)
		if b: return b[0]
		t = typeinfo.get(part + "_parts")
		if t: return t[0]
		return None
	def sp(name): return name and strip_prefix(name)
	lvl = savefile if isinstance(savefile, int) else savefile.level
	obj = Asset(seed=random.randrange(1<<31), is_weapon=is_weapon, type=sp(type), balance=bal,
		brand=sp(balance["manufacturers"][0]), grade=lvl, stage=lvl,
		pieces=[sp(p(n)) for n in partnames(is_weapon)], material=sp(p("material")),
		pfx=sp(typeinfo.get("prefixes", [None])[0]), title=sp(typeinfo.get("titles", [None])[0]))
	if isinstance(savefile, int): return obj
	savefile.add_inventory(obj)
	print("\nGiving", obj)

@synthesizer
def give(savefile, definitions):
	"""Transfer an item from another source, such as the library"""
	print()
	for definition in definitions.split(","):
		[id, *changes] = definition.split("-")
		serial = unarmor_serial(id)
		obj = Asset.decode_asset_library(serial)
		if obj.seed == obj.grade == 50: changes.insert(0, "l") # Can be overridden by another "-l", but normally, assume you want library items at your level.
		obj.seed = random.randrange(1<<31) # Rerandomize the seed
		for change in changes:
			if not change: continue
			c = change[0].lower()
			if c == "l": obj.grade = obj.stage = int(change[1:] or savefile.level)
			# TODO: Add other changes as needed
		savefile.add_inventory(obj)
		print("Giving", obj)

def get_piece_options(obj):
	# TODO: Make use of get_balance_info rather than duplicating the work
	cls = "Weapon" if obj.is_weapon else "Item"
	config = get_asset_library_manager()
	setid, sublib, asset, cat = config["_find_asset"]["BalanceDefs"][obj.balance]
	allbal = get_asset(cls + " Balance")
	# Build up a full list of available parts
	# Assumes that the "mode" is always "Selective" as I don't know how "Additive" works exactly
	checkme = cat + "." + obj.balance
	pieces = [None] * len(obj.partnames)
	while checkme:
		print(checkme)
		if "parts" not in allbal[checkme] and "type" in allbal[checkme]:
			# Some items don't have their parts in their balance definition, but they have
			# a type definition that has them instead.
			typeinfo = get_asset(cls + " Types")[allbal[checkme]["type"]]
			pieces = [p or typeinfo.get(part + "_parts") for p, part in zip(pieces, obj.partnames)]
			# Is it possible to have a base but no parts?
			break
		parts = allbal[checkme]["parts"]
		pieces = [p or parts.get(part) for p, part in zip(pieces, obj.partnames)]
		checkme = allbal[checkme].get("base")
	return [p1 or [p2] for p1, p2 in zip(pieces, obj.pieces)] # Any still unfound, just leave the current piece (or None) in them

@synthesizer
def crossproduct(savefile, baseid):
	baseid, *lockdown = baseid.split(",")
	if "_" in baseid: obj = item(50, baseid) # Looks like a balance name, not an item ID
	else: obj = Asset.decode_asset_library(unarmor_serial(baseid))
	print()
	print("Basis:", obj)
	pieces = get_piece_options(obj)
	interactive = False
	while "interactive or at least once":
		for fixed in lockdown:
			if fixed == "input":
				interactive = True
				continue
			if fixed.startswith("-") and fixed[1:] in obj.partnames:
				# Specify "-delta" to have nothing in slot delta
				pieces[partnames.index(fixed[1:])] = [None]
				continue
			for n, p in enumerate(pieces):
				if fixed in p:
					pieces[n] = [fixed]
					break
			else:
				print("Couldn't find %r to lock down" % fixed)
		# Show the available options and which one is in the basis object
		total = 1
		for i, (n, opts) in enumerate(zip(obj.partnames, pieces)):
			for p in opts:
				if p and obj.pieces[i] and p.endswith(obj.pieces[i]): p = "\x1b[1m%s\x1b[0m" % p
				elif not obj.pieces[i] and p is None: p = "\x1b[1mNone\x1b[0m"
				print(n, p)
				n = " " * len(n)
			if not obj.pieces[i] and None not in opts:
				print(n, "\x1b[1mNone\x1b[0m")
			total *= len(opts)
		print("Will create", total, "objects.")
		lockdown = []
		fixme = interactive and input()
		if fixme == "give" or fixme == "gr" or not fixme:
			for pp in itertools.product(*pieces):
				obj.seed = random.randrange(1<<31)
				obj.grade = obj.stage = savefile.level
				obj.pieces = [piece and strip_prefix(piece) for piece in pp]
				if total < 10: print(">", obj)
				savefile.add_inventory(obj)
			if not fixme: break
			if fixme == "gr": pieces = get_piece_options(obj) # Give and reset
		elif fixme == "q": break # Hitting Enter gives those items and breaks; hitting "q" breaks without.
		elif fixme == "reset": pieces = get_piece_options(obj)
		else: lockdown = [fixme]

parser = argparse.ArgumentParser(description="Borderlands 2/Pre-Sequel save file reader")
parser.add_argument("-2", "--bl2", help="Read Borderlands 2 savefiles",
	action="store_const", const="borderlands 2", dest="game")
parser.add_argument("-p", "--tps", help="Read Borderlands The Pre-Sequel savefiles",
	action="store_const", const="borderlands the pre-sequel", dest="game")
parser.set_defaults(game="borderlands 2")
parser.add_argument("--proton", help="Read savefiles from Proton installation",
	action="store_const", const="proton", dest="platform")
parser.add_argument("--native", help="Read savefiles from native Linux installation",
	action="store_const", const="native", dest="platform")
parser.set_defaults(platform="native")
parser.add_argument("--player", help="Choose which player (by Steam ID) to view savefiles of")
parser.add_argument("--verify", help="Verify code internals by attempting to back-encode", action="store_true")
parser.add_argument("--pieces", help="Show the individual pieces inside weapons/items", action="store_true")
parser.add_argument("--raw", help="Show the raw details of weapons/items (spammy - use loot filters)", action="store_true")
parser.add_argument("--itemids", help="Show the IDs of weapons/items", action="store_true")
parser.add_argument("--synth", help="Synthesize a modified save file", type=synthesizer, nargs="*")
parser.add_argument("-l", "--loot-filter", help="Show loot, optionally filtered to only what's interesting", type=loot_filter, nargs="*")
parser.add_argument("-f", "--file", help="Process only one save file")
parser.add_argument("--dir", help="Specify the savefile directory explicitly (ignores --proton/--native and --player)")
parser.add_argument("--library", help="Add an item ID to the library")
parser.add_argument("--compare", nargs=2, help="Compare two library items (or potential library items)")
args = parser.parse_args()
print(args)

GAME = args.game

# Library of item IDs. Everything here is seed=grade=stage=50 for consistency.
# TODO: Have an easy way to pick and choose, and have them set to the player's level (and randomize the seed)
# TODO: Check variants of each of these and pick out the best. The "# V" tag means I haven't checked variants.
library = {
	"borderlands 2": {
		# Weapons
		"hwAAADLKv4T3Nj+nwWj5D93eEsI037K1X4yK8cYDK8sWhOzS7cRJ": "Lucid Florentine",
		"hwAAADIKvoT3NjynwWgFbZDeYkkhn4u8XMwIu9UDK6MWhOxyZrFJ": "Bulets Go Fasterifed Slagga", # Florentine and Slagga are both slag-em-up SMGs
		"hwAAADKKvoT5NjunwWhxDgXdssM0KLK9XOwK+tQDK6MWrOwC7KRJ": "Bladed Tattler",
		"hwAAADIHS+32AtYAwGjhy0mUAdMnD5q8mOMOut0DK4+33ajR/fdK": "Rapid Infinity",
		"hwAAADLClhT5FjHnwWg5bene4E4lbRm8nSIJxdMDKw8WpengZrVJ": "Onslaught Veruc", # V
		"hwAAADLKvwT4Nj2nwWiJr3XdckI2/9u4XoyK89oDK8MWjOyybQZI": "Rightsizing Yellow Jacket",
		"hwAAADIHS231AtYAwGgVywGYwdYnYey8nQMMutMDK4uw7aiB+fdK": "Corrosive Teapot", # Bandit grip and Jakobs sight - other options available
		"hwAAADLKvwT5NtYAwGgtbVDfok4hoqu8XywJu8cDK8sWhOzSZrFJ": "Fervid Hellfire",
		"hwAAADIHS20A5TXPwWjVy1Ge8dMnX1a8mQMPut8DK7+3zagx/fdK": "Crammed Unkempt Harold",
		"hwAAADIKvgT4Nj2nwWj5L33dMkI07Nm1X2wK9sYDK8sWhOzybYRJ": "Consummate Crit",
		# Grenades
		"BwAAADLCuhHxmSU8wOjSDKEfogGraRu+EzziescQoXr3uq5NbvU": "Longbow Bonus Package",
		"BwAAADLCudH52S+8IhTTDKHfpQHpUxu2E0jiWscQ4X33uq5N7vY": "Longbow Breath of Terramorphous",
		"BwAAADLCuhH52daAIhTTDKEfpQHy0xu5E0biWscQ4Xr3uq5N7v8": "Longbow Pandemic",
		"BwAAADJCvDLxmSU8wOjSDKFfgyJbuBi6EQnKascQIW/Uuq5QbvU": "Longbow Meteor Shower",
		"BwAAADLCshH52daAN1TfzH4jgiDqZBK8CQ+q6sYQYZkLt49NLv4": "Fire Storm",
		"BwAAADLCstH52daAN9TfzH6jgCBJjxK8CQeq6sYQYZkLtI9Nrv8": "Lightning Bolt",
		"BwAAADLCshH52daAN9TfzH4jgCCRihK8CQWq6sYQYZkLtY9NLv4": "Fireball",
		"BwAAADLCstH5WS68N9TfzH7jgCDRYRK8CQGq6sYQYZlLtI9Nbv8": "Magic Missile",
		"BwAAADLCstH5WS68NxTfzH7jgCB58xK8CQOq6sYQYZnLt49Nbv8": "Magic Missile (rare)", # Synthesized, unconfirmed.
		"BwAAADLCstH52daAN1TfzH7jgSBNXhK8CQ2q6sYQYZnLtI9Nrv8": "Chain Lightning",
		"BwAAADLCuhH52daAIhTTDKFfpQEo1Ru5EzriWscQ4Xr3uq5NLv4": "Longbow Fire Bee",
		"BwAAADLCshH5WS68N9TfTIsfpgHW0Bu9E1Ti+sYQYXo3pa5Nrv8": "Shock Kiss of Death",
		"BwAAADLCuhHxWS48wOjSzH5jrwGGwRu1E0LiescQYZkLuq5QbvU": "Rolling Thunder",
		"BwAAADLCutH52daAItTZDJ7fpAHhRBu/Ez7iuscQIX23uq5NLv4": "Sticky Longbow Bouncing Bonny",
		"BwAAADICvTLxWSW8IhTfDJ5fhCJ0iRi7EQvK6sYQoX23uu5QbvU": "O-Negative",
		"BwAAADJCs/L52daAItTZDKGfjSJ5qBi5EQ/KqscQ4W7Uuq5Q7v8": "Corrosive Crossfire",
		# Shields
		"BwAAADIiS20A5dYAwOjK7H6jgCEaBxK8Cgm6CsYQ4WQwsClY6fQ": "Blockade",
		"BwAAADIFS20A5dYAwGicy37j2gbb3xuqDW6qOccQYWcwsClY6aM": "The Bee",
		"BwAAADIFS20A5dYAwOiey36j2QbGjRuuDVaqWccQ4WcwsakEKaA": "The Transformer",
		"BwAAADIFS20A5dYAwCjOb4E8gCJh9Ri8EQXKSscQ4WcwsSlXaew": "Sponge",
		"BwAAADIFS20A5dYAwOjFy36jlwaOWhu9DQCq+cYQIWYwsKlW6fs": "Flame of the Firehawk",
		"BwAAADIFS20A5dYAwOjWS7qYugbmPhu7DWqq+cUQYWcwsSlYaeg": "Chitinous Turtle Shield", # Massive capacity, slow recharge.
		"BwAAADIFS20A5dYAwOjWy76YugZn0hu7DWqq+cUQ4WcwtqlWaeg": "Selected Turtle Shield", # A bit less capacity but better recharge
		"BwAAADIFS20A5dYAwGidy36j2ga/nRukDXaq+cYQ4WcwsalW6aw": "Black Hole", # Good capacity, moderate nova
		"BwAAADIFS20A5dYAwGidy4yY2gbR0RukDXaq+cYQIWfwsWlX6aw": "Grounded Black Hole", # Great nova, lower capacity
		"BwAAADIiS20A5dYAwGjK7H4jgSGEjRK9Cgu66sYQ4WcwsalWqfU": "Antagonist",
		# Snipers
		"hwAAADINsYrkKkqfwWh1jdAYI8ki6Ti8n8yJu8cDK+/25C2z5zJN": "Banbury Volcano", # Hot (obviously)
		"hwAAADJNsQrkKkufwWiBjagY08siXTC8n8yLu8cDKzv21C1D5FJN": "Monstrous Chère-amie", # Elec
		"hwAAADKNsQoA5dYAwGidjDhd4s8iQdS8mCyKu9EDK2P17C3D7zJN": "Kull Trespasser", # Hard
		"hwAAADINsArjKkufwWgdL60Yg0A0ere9n6yL+cYDKzv21C2jbARN": "Monstrous Pimpernel", # Slag
		"hwAAADLNsYrjKkufwWhFjagY08kiKwG8n0yJu8cDK+/21C3z5DJN": "Monstrous Railer", # Acid
		"hwAAADINsArkKkufwWhljZgYA8kiXSS8nAyOu9sDKwv21C3z5xJN": "Resource Invader", # Burst-fire elec, good for bosses maybe
		# Kabooms
		"hwAAADJEr5j3Dj/XwWihrbFeUUcm76O8XCOIxdkDKwPWvW4Ba9ZI": "Bonus Launcher",
		"hwAAADJErxj2Dj/XwWjRr6FeoUkmDs28XyOOxdUDKzvWvW6xZrZI": "Roket Pawket PRAZMA CANON",
		"hwAAADJEr5j3DjXXwWi5rcldgUomp+u8XYOIxd8DKwvWlW7Ba7ZI": "derp Duuurp!",
		"hwAAADIErpj3DjzXwWjRrylcUkUmgjS8XwOKxdUDK2fUlW7Ba9ZI": "hurty Zooka!",
		"hwAAADKEr5j3DjzXwWgRrSlcsk4mr128X4OJxdUDK2fUlW7BZnZI": "hurty Roaster",
		"hwAAADIErpj3DjLXwWhBreldMUgm5Qq8XOOIxdkDKwPWlW5BZ5ZI": "Bustling Bunny",
		"hwAAADJEr5j3DjPXwWjRrwFdUUcmYiK8XwOKxdUDK2fUtW4Ba9ZI": "Speeedee Launcher",
		"hwAAADLEr5j3DjHXwWi5rWld0UUmSgG8XYOIxd8DKwvWpW4xa5ZI": "dippity boom",
		"hwAAADJErpj3DjPXwWixrQFdEUgmCTC8X6OIxdUDKzvWtW6BZNZI": "Speeedee Badaboom", # Synthesized, unconfirmed
		# Relics
		"BwAAADIBS20A5S1fPXd/xYkbgM3MtQqOBQSK/JcqOGg": "Heart of the Ancients", # SMG variant
		"BwAAADI+S20AZS+/OldkWoEUi/wcxQqOBQTKBSjdR5k": "Proficiency Relic",
		"BwAAADI+S20A5SO/OlcyAoEci+wcxQqOBQTKBSjdR5k": "Vitality Relic",
		"BwAAADI+S20AJSK/O1f9WYEbi/4cpQqOxfu1/BfdR5k": "Tenacity Relic",
		"BwAAADI+S20AZSO/Old8zIEdi/IcxQqOhQ3KBSjdR5k": "Stockpile Relic", # +4 Grenades, regardless of level
		"BwAAADI+S20AZS1fPXdS+IkdgMHMtQqOBQUK/BfdR5k": "Skin of the Ancients", # Vary the Alpha component to change the element
		"BwAAADIBS20A5SK/O1cVT4ECi6gcxQqOBQSK/Bfdx24": "The Afterburner",
		# Unconfirmed or uncategorized
		"hwAAADLClhT3Fj/nwWgBbWHeQE4l+Eu8nIIOxdUDK6MWpekQYLVJ": "Wyld Asss BlASSter",
		"hwAAADJKvgT5Nj+nwWh9bdjewksh0OW8X4wIu8cDK8sWjOxybfFJ": "Lucid SubMalevolent Grace",
		"hwAAADLKv4T4Nj6nwWh9bQDeAkQh1k28X4wIu8cDK8sWhOwSbbFJ": "Apt Venom",
		"hwAAADIKvoT3NjinwWjpbLDYEk8h0pa8X4wJu8cDKx8WrOwSYPFJ": "Feculent Chulainn",
		"BwAAADIFS20A5dYAwOjQy7OYrwaMDxu5DWaqGcYQoWfwtulXae4": "Patent Adaptive Shield",
		"hwAAADIKvgT4NjinwWj5L13YMkI0xaK1X2wK9sYDKx8WhOzybeRJ": "Miss Moxxi's Crit",
		"hwAAADIClRT4FjvnwWjNLx3foEI031G/mAKK99wDK/cWnelQbWRJ": "Corrosive Kitten",
		"BwAAADIFS20A5dYAwOjdi5GY0wbHwxuzDYqq+cYQoWcwsKlWabU": "Majestic Corrosive Spike Shield", # V
		"hwAAADLLqAb1MievwWh9TTiZ4skhwIu8HeyIutUDK+82jK6S5/FJ": "Sledge's Shotgun",
		"hwAAADLLqAbzMiavwWgFTVidIskhXYm8HwyJutkDK8c2/K5y5tFJ": "Original Deliverance", # V
		"hwAAADKLr4bzMjuvwWj1L5WfIkI0CkG/HqyK99oDK/c27K6ybSRI": "Practicable Slow Hand", # Better damage and fire rate
		"hwAAADKLr4bzMiSvwWj1L52eIkI0fK6/HqyK99oDK/c27K6ybSRI": "Scalable Slow Hand", # Better accuracy and mag
		"hwAAADJClhQA5T7nwWjJbDHeAE4lcVO8n2IJxd8DK7MWlemgZtVJ": "Slippery KerBlaster",
		"hwAAADJEr5j3DjPXwWhtLx1dAUA0ayS9XQOI+d4DK0vUlW4hb4RI": "fidle dee 12 Pounder",
		"hwAAADIHS231AjTPwWg1zHGesdMnRfi8ncMOutMDK/+3xaix4jdJ": "Neutralizing Hornet",
		# Mechromancer:
		"hwAAADLLqAYA5dYAwGh9L3VcaEA0OkK9HIyI+dADK8s05K6Sb8RJ": "Captain Blade's Orphan Maker",
		"BwAAADI+S20A5dYAwCjOToo8gAPythm2HQECKscQoWO1tGxQLAs": "Legendary Mechromancer",
		"BwAAADI+S20A5dYAwOjJzogdgAPgyRm9HQcC6sYQoWO1tGxQLAs": "Slayer of Terramorphous",
		"BwAAADI+S20ApS1fPXfwpIkegMfM1QqOBQSK/9coeJk": "Bone of the Ancients",
		"BwAAADI+S20A5dYAwOjOjoI8gAM37hGpHAkK6sYQoWO1tGxQLAs": "Legendary Catalyst",
		# Siren:
		"BwAAADI+S20A5dYAwOjJzogdgAM/+xudEXKr+cYQoWO1tGxQLAs": "Slayer Of Terramorphous Class Mod",
		"BwAAADI+S20A5dYAwKjODoE8gAN1wBG8HAcK6sYQoWO1tGxQLAs": "Legendary Binder",
		"BwAAADI+S20A5dYAwCjJjpkdgAMXxxubEXyr+cYQoWO1tGxQLAs": "Legendary Siren",
		"BwAAADI+S20A5dYAwKjOzpsdgAPwuBuUEX6r+cYQIWO1tGxQLAs": "Chrono Binder", # Left tree focus
		"BwAAADI+S20A5dYAwKjODpodgAMyehuUEX6r+cYQoWG1tGxQLAs": "Hell Binder", # Right tree focus
		# Assassin:
		"BwAAADI+S20A5dYAwOjJzogdgAOmFhufEZarmccQoWN1t2xQLAs": "Slayer Of Terramorphous",
		"BwAAADI+S20A5dYAwGjJzogdgANW6BufEZarmccQoWP1t+xQLAs": "Slayer Of Terramorphous",
		# Merc:
		"BwAAADI+S20A5dYAwKjOzogdgAM/jBueEYCr2ccQoWN1t6xQLAs": "Slayer Of Terramorphous",
		"BwAAADI+S20A5dYAwKjOTqMdgANlvhugEYyrWccQoWG1tGxQLAs": "Lucky Hoarder",
		"BwAAADI+S20A5dYAwKjOzoA8gAPF5RG0HA0KSscQoWO1tGxQLAs": "Legendary Hoarder", # Synthesized, unconfirmed.
		"BwAAADI+S20A5dYAwCjJDoI8gAP3KRG7HA0KascQoWO1tGxQLAs": "Legendary Gunzerker",
		"BwAAADI+S20AJSlfPXdifokcgMPMlQqOBQSK/RcqeJk": "Blood of the Ancients", # SMG and Launcher ammo - other options available
		# Soldier:
		"BwAAADI+S20A5dYAwOjJzqAdgAMAXhuVEYKr2ccQoWO1t6xQLAs": "Legendary Berserker Class Mod", # V
		"BwAAADI+S20A5dYAwOjOzqAdgANdoxuVEYKr2ccQoWO1t6xRLAs": "Legendary Berserker Class Mod",
		"BwAAADI+S20A5dYAwOjJzogdgAN14hu8EWyruccQoWO1tOxQLAs": "Slayer Of Terramorphous",
		"BwAAADI+S20A5dYAwKjOTosdgAOj/Ru9EXSruccQIWB1tmxQLAs": "Diehard Veteran Class Mod",
		# Psycho:
		"BwAAADI+S20A5dYAwCjJDog8gANNZh22HAUK6sYQoWM1t+xQLAs": "Slayer of Terramorphous",
		"BwAAADI+S20A5dYAwOjJDog8gAN2DR22HAUK6sYQoWO1t6xQLAs": "Slayer of Terramorphous",
	},
	"borderlands the pre-sequel": {
		# Lasers
		"igAAADJ+ogDSPtYAPme6Lrha4k4gJV28ni4JxtkBKztVdG/CaBC3": "E-GUN",
		"igAAADJIsoD8PtYAPmfiDRUd2ME0uay5nk6I/9gBK6dUPG1S7sRI": "Tannis' Laser of Enlightenment", # V
		"igAAADJIsoD7PtYAPmcCL3BZUkkgN2G8ni4LxtkBK6dULG1CbrBI": "Miss Moxxi's Vibra-Pulse",
		"igAAADLIr4D8PtYAwGh9LuhaQk4gIsK8nG4JxtcBK8dV/G7ya5BF": "The ZX-1",
		"igAAADIIsgAA5dYAPmfmDU0dKME0sGS5no6I/9gBK6dUJG3S7oRI": "MINAC's Atonement", # V
		"igAAADLIsgAA5dYAPmfmDU0dKME0nDO5no6I/9gBK6dUPG3S7sRI": "MINAC's Atonement", # V
		"igAAADJIsgAA5dYAPmfmDU0dKME07Ve5no6I/9gBK6dUPG3S7sRI": "MINAC's Atonement", # V
		"igAAADLIsgD7Pgq3P2eWLDBaQk8ggYK8nY4OxsUBK0NVNG3yYFBI": "Excalibastard",
		"igAAADIIsoD7PtYAPmfCDcUd+MA0q1K5nq6L/9gBK1dVNG0C72RI": "Thunderfire", # V
		"igAAADJIsoD8Pgu3P2e2LsBYEk4gHLa8nc4KxtUBKxNVPG2yaLBI": "Lensed Mining Laser", # V
		"igAAADKIsoD8Pgu3wZeYD+1YQksgXUy5ne6K/9QBK0NVJG0ybLBI": "Heated Subdivided Splitter", # V
		"igAAADKIsoD8Pgu3zZeYDxVYAksgRBy5ne6K/9QBK0NVLG0SbFBI": "Catalyzing Lancer Railgun", # V
		"igAAADIIsgD7Pgu35ZeYDz1fokggSRW5ne6K/9QBK0NVJG0ibHBI": "Niveous Zero Beam", # V
		# SMGs
		"igAAADKWt7z+RgtH6Zf0DQUYaMo0lK25XAiN/9wBK8eUj+0FbB9K": "%Cu+ie^_^ki||er",
		"igAAADLWsDzyRgpHP2eeDf3YpcY0Et25WOiI/8QBK1OVl+1F6eRL": "Incorporated Cheat Code", # V
		"igAAADKWtzzyRg1HP2eeDS3YpcY0kga5WOiI/8QBK1OVj+1F6QRK": "Accessible Cheat Code", # V
		"igAAADKWsDzyRghHP2eeDY3YpcY0vJe5WOiI/8QBK1OVn+1F6aRL": "All-In Cheat Code", # V
		"igAAADKWsDz/RglH0ZfkDjXfBUsvXJu5XmiJ/9YBK7OUj+0VbP9L": "Deft Fox", # V
		# Launchers
		"igAAADJTvrb0UiFvxZeQDh2flMstKU25nq+M/9ABK7s0t6wk7z1J": "Large Spread", # V
		"igAAADJTvrb0UitvwWitDz2e9MM0zHi+XxSL+9IBK2s1v6zU7ARJ": "Berrigan", # V
		"igAAADLTv7b0Ui9vyZeQDs2fRMEtgma5nq+M/9ABK7s0p6wU7x1J": "Rocket Speed Launcher", # V
		"igAAADLTvzbzUihvP2fOT8CYRMIhAVi8ng+KxtEBKxc0p6xU7fFK": "Sparkling Volt Thrower", # V
		# Snipers
		"igAAADIPtCIA5Qs/P2fSz7AftsMjt7i8nWiKxMcBK6t0vi0W7VNI": "Tl'kope Razorback", # V
		"igAAADIZsaLxeg0/P2fmzyicw8Mja3u8mKiKxNMBK0N1/q3z7VNK": "The Machine", # V
		"igAAADIZtCLweg8/15dYDm0flscoKae5n6iO/9QBK2N11i2G7XhK": "Auditing Sniper Rifle", # V
		# Grenades
		"CgAAADKHslTznCI5wCjTCaHagAGPLBu9DQRSO+cQoWZ3tKtRa/0": "Bonus Package",
		"CgAAADKHslTz3NaAONHRCZ4agQFt1Bu+DQZS2+cQ4Wb3tatRK/A": "Quasar", # V
		"CgAAADLHoFT53Dx5OFHXCZFagQExsRu8CABSG+cQIWY3vKtRa/0": "Explosive Kiss of Death", # V
		# Shields
		"CgAAADIJS20A5dYAwGjeh5HU1grlMBugC5qCGecQ4WF8sKVTJcQ": "Majestic Incendiary Spike Shield", # V
		"CgAAADIjS20A5dYAwKjI7X6jgSDCqB6+HQESyucQIWF8sKVTJfU": "Shield of Ages",
		"CgAAADIjS20A5dYAwKjJ7X7jgiA5wx6/HQMSiucQIW58s6VTZfY": "Naught",
		"CgAAADIJS20A5dYAwOjBx36j0ArCAxupC1qCOecQoWH8sCVSZdo": "Asteroid Belt", # V
		"CgAAADIJS20A5dYAwOjBx37j0ArAkhuqC2SCmeYQYWB8seVRJdo": "Miss Moxxi's Slammer", # V
		"CgAAADIJS20A5dYAwCjtx37jsQqVaBuvC16C2ecQoWE8sKVRpdY": "Prismatic Bulwark",
		"CgAAADIjS20A5dYAwGjJ7cNUgyDtQx64HQ0SiuYQIWF8kyVSZfc": "Hippocratic M0RQ",
		"CgAAADIJS20A5dYAwGjix34jvQpY5RuyC1SCGecQIWB8sSVR5dE": "Avalanche", # Synth
		"CgAAADIJS20A5dYAwOjtx36jsQrTGhutC1KCuecQIWF8sKV25dY": "Kala", # Synth
		"CgAAADIJS20A5dYAwKjtx35jsQokxBuuC1yCuecQoWH8saVRJdU": "The Sham", # Synth
		"CgAAADIJS20A5dYAwKjqx34jxAr3+Bu3C06CGecQIWF8sCVSZdA": "Supernova", # Synth
		"CgAAADIjS20A5dYAwOjI7X4jgSDAXB69HQcSyucQoW58sCVSJfQ": "Rerouter", # Synth
		# Oz Kits
		"CgAAADI+S20ApSB4OlA1MJNbkwVxmhunClJy2+cQ4WezStKvEgs": "Voltaic Support Relay",
		# Gladiator
		"CgAAADI+S20A5dYAwCjYD5VdgALTFhuoEziKuecQYXW0pG1ALQs": "Celestial Gladiator Title.Title_ClassMod",
		"CgAAADI+S20A5dYAwOjYj5BdgALHthutEz6KmeYQoWu0pG1ALQs": "Eternal Protector Title.Title_ClassMod",
		"CgAAADI+S20A5dYAwOjYT5VdgAJr0xupEzqK2ecQYXU0pC1fLQs": "Eridian Vanquisher Title.Title_ClassMod", # V
		"CgAAADI+S20A5dYAwOjZD4F8gALFKhm9HT8q6ucQYXV0pG1ALQs": "Chronicler Of Elpis Title.Title_ClassMod", # V
		# Prototype
		"CgAAADI+S20A5dYAwCjYj4NegAJuiBu8DCqKueYQYW20pG1fLQs": "Stampeding Brotrap Title.Title_ClassMod", # V
		"CgAAADI+S20A5dYAwKjYz4NegALL8Ru8DDSKueYQ4Wt0pG1fLQs": "Inspirational Brotrap Title.Title_ClassMod", # V
		"CgAAADI+S20A5dYAwKjZT4degAIo+hu5DCqKWecQoW10pC1ALQs": "Loot Piñata Title.Title_ClassMod", # V
		"CgAAADI+S20A5dYAwOjZD4F8gALIaBm5HTsq6ucQYXX0pa1fLQs": "Chronicler Of Elpis Title.Title_ClassMod", # V
		# Baroness
		"CgAAADI+S20A5dYAwOjZT4p8gAIwQh2yHAMCCucQIWp0pK1fLQs": "High-and-Mighty Gentry Title.Title_ClassMod", # only a blue, need a purple
		"CgAAADI+S20A5dYAwKjYD4Z8gALIJB2wHA0C6ucQYWq0pG1ALQs": "Posh Blue Blood Title.Title_ClassMod",
		"CgAAADI+S20A5dYAwKjYD4B8gAK3FB2+HA8CyucQYXW0pG1ALQs": "Celestial Baroness Class Mod", # Synth
		"CgAAADI+S20A5dYAwKjYT4tegALZ1R29HAkCyucQYXW0pG1ALQs": "Eridian Vanquisher Class Mod", # Synth

		# Uncategorized
		"igAAADLIsoD8PtYAwGgdLRBYQksgRv28ne4JxtUBK5dULG0ybNBI": "Catalyzing Subdivided Splitter",
		"igAAADKIsoD8Pgu3wZeYD+1YQksgXUy5ne6K/9QBK0NVJG0ybLBI": "Heated Subdivided Splitter",
		"igAAADLTvzbzUihvP2fOT8CYRMIhAVi8ng+KxtEBKxc0p6xU7fFK": "Sparkling Volt Thrower",
		"igAAADISS+3rVgZnP2fuDa0e6MY0XmG53Q+J/9wBKy8U5+8U6YRI": "Party Popper",
	},
}

# Requires access to the Gibbed data files.
ASSET_PATH = "../GibbedBL2/Gibbed.Borderlands%s/projects/Gibbed.Borderlands%s.GameInfo/Resources/%s.json"
def get_asset(fn, cache={}):
	if fn not in cache:
		if GAME == "borderlands 2": path = ASSET_PATH % ("2", "2", fn)
		else: path = ASSET_PATH % ("Oz", "Oz", fn)
		with open(path, "rb") as f: cache[fn] = json.load(f)
	return cache[fn]

def get_asset_library_manager():
	config = get_asset("Asset Library Manager")
	if "_sets_by_id" not in config:
		# Remap the sets to be keyed by ID - it's more useful that way.
		config["_sets_by_id"] = {set["id"]: set for set in config["sets"]}
	# Build a mapping from item identifier to (set,subid,asset) triple.
	if "_find_asset" not in config:
		cfg = config["_find_asset"] = collections.defaultdict(dict)
		for set in config["sets"]:
			for field, libinfo in set["libraries"].items():
				for sublib, info in enumerate(libinfo["sublibraries"]):
					for asset, name in enumerate(info["assets"]):
						if args.verify and name in cfg[field]:
							print("Got duplicate", field, name, cfg[field][name], (set["id"], sublib, asset))
						cfg[field][name] = set["id"], sublib, asset, info["package"]
	return config

def get_balance_info(is_weapon, balance):
	cls = "Weapon" if is_weapon else "Item"
	allbal = get_asset(cls + " Balance")
	if balance not in allbal:
		# If something goes wrong, this will probably KeyError either looking up the BalanceDef, or in the subsequent lookup in allbal.
		config = get_asset_library_manager()
		setid, sublib, asset, cat = config["_find_asset"]["BalanceDefs"][balance]
		balance = cat + "." + balance
	info = allbal[balance]
	base = get_balance_info(is_weapon, info["base"]) if "base" in info else {"parts": { }}
	ret = {k:v for k,v in base.items() if k != "parts"}
	for k,v in info.items():
		if k == "parts":
			mode = v.get("mode")
			# I *think* that Complete means to ignore the base? There never seems to be a base anyhow.
			if mode == "Complete": ret["parts"] = { }
			else: ret["parts"] = {k:v for k,v in base["parts"].items() if k != "mode"}
			for part, opts in v.items():
				if part == "mode": continue
				# Don't understand Additive. It doesn't seem to be used with both a base and parts.
				# Not sure if this is correct or if things are done in the right order or anything.
				if mode == "Additive" and isinstance(ret["parts"].get(part), list) and isinstance(opts, list):
					ret["parts"][part] = opts + ret["parts"][part]
				else:
					ret["parts"][part] = opts
		elif k != "base": ret[k] = v # Don't copy in the base once it's rendered
	return ret

class ConsumableLE(Consumable):
	"""Little-endian bitwise consumable"""
	def get(self, num):
		return super().get(num)[::-1]
	@classmethod
	def from_bits(cls, data):
		"""Create a bitfield consumable from packed eight-bit data"""
		return cls(''.join(format(x, "08b")[::-1] for x in data))

def bogocrypt(seed, data, direction="decrypt"):
	if not seed: return data
	split = (seed % 32) % len(data)
	if direction == "encrypt": # Encrypting splits first
		data = data[split:] + data[:split]
	if seed > 1<<31: seed |= 31<<32 # Emulate an arithmetic right shift
	xor = seed >> 5
	data = list(data)
	for i, x in enumerate(data):
		# ??? No idea. Got this straight from Gibbed.
		xor = (xor * 0x10A860C1) % 0xFFFFFFFB
		data[i] = x ^ (xor & 255)
	data = bytes(data)
	if direction == "encrypt": return data
	return data[-split:] + data[:-split] # Decrypting splits last

@dataclass
class Asset:
	seed: None
	is_weapon: None
	type: "*Types"
	balance: "BalanceDefs"
	brand: "Manufacturers"
	# There are two fields, "Grade" and "Stage". Not sure what the diff
	# is, as they seem to be equal (except when grade is 0 and stage is 1?).
	grade: int
	stage: int
	pieces: ["*Parts"] * 8
	material: "*Parts"
	pfx: "*Parts"
	title: "*Parts"
	@property
	def partnames(self): return partnames(self.is_weapon) # Convenience lookup property

	@classmethod
	def decode_asset_library(cls, data):
		orig = data
		seed = int.from_bytes(data[1:5], "big")
		dec = data[:5] + bogocrypt(seed, data[5:], "decrypt")
		if args.verify:
			reconstructed = dec[:5] + bogocrypt(seed, dec[5:], "encrypt")
			if data != reconstructed:
				print("Imperfect reconstruction of weapon/item:")
				print(data)
				print(reconstructed)
				raise AssertionError
		data = dec + b"\xFF" * (40 - len(dec)) # Pad to 40 with 0xFF
		crc16 = int.from_bytes(data[5:7], "big")
		data = data[:5] + b"\xFF\xFF" + data[7:]
		crc = binascii.crc32(data)
		crc = (crc >> 16) ^ (crc & 65535)
		if crc != crc16: raise ValueError("Checksum mismatch")
		config = get_asset_library_manager()
		# The first byte is a version number, with the high
		# bit set if it's a weapon, or clear if it's an item.
		is_weapon = data[0] >= 128
		weap_item = "Weapon" if is_weapon else "Item"
		if (data[0] & 127) != config["version"]: raise ValueError("Version number mismatch")
		uid = int.from_bytes(data[1:5], "little")
		if not uid: return None # For some reason, there are a couple of null items at the end of inventory. They decode fine but aren't items.
		setid = data[7]
		bits = ConsumableLE.from_bits(data[8:])
		def _decode(field):
			cfg = config["configs"][field]
			asset = bits.get(cfg["asset_bits"])
			sublib = bits.get(cfg["sublibrary_bits"] - 1)
			useset = bits.get(1)
			if "0" not in (useset+sublib+asset): return None # All -1 means "nothing here"
			cfg = config["_sets_by_id"][setid if useset == "1" else 0]["libraries"][field]
			# print(field, cfg["sublibraries"][int(sublib,2)]["assets"][int(asset,2)])
			return cfg["sublibraries"][int(sublib,2)]["assets"][int(asset,2)]

		ret = {"seed": seed, "is_weapon": is_weapon}
		for field, typ in cls.__dataclass_fields__.items():
			typ = typ.type
			if typ is None:
				continue # Not being decoded this way
			if typ is int:
				ret[field] = int(bits.get(7), 2)
			elif isinstance(typ, str):
				ret[field] = _decode(typ.replace("*", weap_item))
			elif isinstance(typ, list):
				ret[field] = [_decode(t.replace("*", weap_item)) for t in typ]
			else:
				raise AssertionError("Bad annotation %r" % typ)
		ret = cls(**ret)
		if args.verify:
			if ret.encode_asset_library() != orig:
				raise AssertionError("Weapon reconstruction does not match original: %r" % ret)
		return ret

	def encode_asset_library(self):
		# NOTE: Assumes that at least one decode has been done previously.
		bits = []
		config = get_asset_library_manager()
		fields = []
		needsets = {0}
		def _encode(field, item):
			cfg = config["configs"][field]
			fields.append("%s-%d-%d" % (field, cfg["asset_bits"], cfg["sublibrary_bits"]))
			if item is None:
				bits.append("1" * (cfg["asset_bits"] + cfg["sublibrary_bits"]))
				return
			setid, sublib, asset, cat = config["_find_asset"][field][item]
			needsets.add(setid)
			bits.append(format(asset, "0%db" % cfg["asset_bits"])[::-1])
			bits.append(format(sublib, "0%db" % (cfg["sublibrary_bits"]-1))[::-1])
			bits.append("1" if setid else "0")
		weap_item = "Weapon" if self.is_weapon else "Item"
		for field, typ in self.__dataclass_fields__.items():
			typ = typ.type
			if typ is None:
				continue # Not being encoded this way
			if typ is int:
				bits.append(format(getattr(self, field), "07b")[::-1])
			elif isinstance(typ, str):
				_encode(typ.replace("*", weap_item), getattr(self, field))
			elif isinstance(typ, list):
				for t, piece in zip(typ, getattr(self, field)):
					_encode(t.replace("*", weap_item), piece)
		if len(needsets) > 2: print("Need multiple set IDs! Cannot encode.", needsets)
		# Note that needsets might still be {0}, in which case we'll render a setid of 0.
		bits = "".join(bits)
		bits += "1" * (8 - (len(bits) % 8))
		data = int(bits[::-1], 2).to_bytes(len(bits)//8, "little")
		data = (
			bytes([config["version"] | (128 if self.is_weapon else 0)]) +
			self.seed.to_bytes(4, "big") + b"\xFF\xFF" + bytes([max(needsets)]) +
			data
		)
		data = data + b"\xFF" * (40 - len(data)) # Pad for CRC calculation
		crc = binascii.crc32(data)
		crc = (crc >> 16) ^ (crc & 65535)
		# data = (data[:5] + crc.to_bytes(2, "big") + data[7:]).rstrip(b"\xFF")
		# print(' '.join(format(x, "08b")[::-1] for x in data))
		# print(' '.join(format(x, "08b")[::-1] for x in (dec[:5] + b"\xFF\xFF" + dec[7:])))
		return data[:5] + bogocrypt(self.seed, (crc.to_bytes(2, "big") + data[7:]).rstrip(b"\xFF"), "encrypt")

	def get_title(self):
		if self.type == "ItemDefs.ID_Ep4_FireHawkMessage": return "FireHawkMessage" # This isn't a real thing and doesn't work properly. (It'll be in the bank when you find out about the Firehawk.)
		weap_item = "Weapon" if self.is_weapon else "Item"
		config = get_asset_library_manager()
		setid, sublib, asset, cat = config["_find_asset"][weap_item + "Types"][self.type]
		typeinfo = get_asset(weap_item + " Types")[cat + "." + self.type]
		if typeinfo.get("has_full_name"):
			# The item's type fully defines its title. This happens with a number
			# of unique and/or special items.
			return typeinfo["name"]
		# Otherwise, build a name from a prefix (possibly) and a title.
		# The name parts have categories and I don't yet know how to reliably list them.
		names = get_asset(weap_item + " Name Parts")
		pfxinfo = None
		if self.pfx:
			setid, sublib, asset, cat = config["_find_asset"][weap_item + "Parts"][self.pfx]
			pfxinfo = names.get(cat + "." + self.pfx)
			# pfxinfo has a name (unless it's a null prefix), and a uniqueness flag. No idea what that one is for.
		if self.title:
			setid, sublib, asset, cat = config["_find_asset"][weap_item + "Parts"][self.title]
			titinfo = names.get(cat + "." + self.title)
			title = titinfo["name"] if titinfo else self.title
		else: title = "<no title>"
		if pfxinfo and "name" in pfxinfo: title = pfxinfo["name"] + " " + title
		return title

	def __repr__(self):
		if self.grade == self.stage: lvl = "Lvl %d" % self.grade
		else: lvl = "Level %d/%d" % (self.grade, self.stage)
		type = self.type.split(".", 1)[1].replace("WT_", "").replace("WeaponType_", "").replace("_", " ")
		ret = "%s %s (%s)" % (lvl, self.get_title(), type)
		if args.itemids: ret += " {%s}" % armor_serial(self.encode_asset_library())
		if args.pieces: ret += "\n" + " + ".join(filter(None, self.pieces))
		if args.raw: ret += "\n" + ", ".join("%s=%r" % (f, getattr(self, f)) for f in self.__dataclass_fields__)
		return ret
	#if args.raw: del __repr__ # For a truly-raw view (debugging mode).

def decode_tree(bits):
	"""Decode a (sub)tree from the given sequence of bits

	Returns either a length-one bytes, or a tuple of two trees (left
	and right). Consumes either a 1 bit and then eight data bits, or
	a 0 bit and then two subtrees.
	"""
	if bits.get(1) == "1": # Is it a leaf?
		return int(bits.get(8), 2)
	# Otherwise, it has subnodes.
	return (decode_tree(bits), decode_tree(bits))
def huffman_decode(data, size):
	bits = Consumable.from_bits(data)
	root = decode_tree(bits)
	global last_huffman_tree; last_huffman_tree = root
	ret = []
	while len(ret) < size:
		cur = root
		while isinstance(cur, tuple):
			cur = cur[bits.get(1) == "1"]
		ret.append(cur)
	# The residue doesn't always consist solely of zero bits. I'm not sure
	# why, and I have no idea how to replicate it. Hopefully it doesn't
	# matter.
	residue = bits.peek()
	global last_huffman_residue; last_huffman_residue = residue
	if len(residue) >= 8: raise ValueError("Too much compressed data - residue " + residue)
	return bytes(ret)

def huffman_encode(data):
	if not data: return data # Probably wrong but should never happen anyway
	# First, build a Huffman tree by figuring out which bytes are most common.
	counts = collections.Counter(data)
	while len(counts) > 1:
		# Pick the two least common and join them
		(left, lfreq), (right, rfreq) = counts.most_common()[-2:]
		del counts[left], counts[right]
		counts[(left, right)] = lfreq + rfreq
	[head] = counts # Grab the sole remaining key
	if args.verify: head = last_huffman_tree # Hack: Reuse the tree from the last decode (gives bit-for-bit identical compression)
	# We now should have a Huffman tree where every node is either a leaf
	# (a single byte value) or a tuple of two nodes with approximately
	# equal frequency. Next, we turn that tree into a bit sequence that
	# decode_tree() can parse, and also (for convenience) flatten it into
	# a lookup table mapping byte values to their bit sequences.
	bits = {}
	ret = []
	def _flatten(node, seq):
		if isinstance(node, tuple):
			ret.append("0")
			_flatten(node[0], seq + "0")
			_flatten(node[1], seq + "1")
		else:
			ret.append("1" + format(node, "08b"))
			bits[node] = seq
	_flatten(head, "")
	# Finally, the easy bit: turn every data byte into a bit sequence.
	ret.extend(bits[char] for char in data)
	ret = "".join(ret)
	spare = len(ret) % 8
	if spare:
		# Hack: Reuse the residue from the last decode. I *think* this is just
		# junk bits that are ignored on load.
		if args.verify and len(last_huffman_residue) == 8-spare: ret += last_huffman_residue
		else: ret += "0" * (8-spare)
	return int(ret, 2).to_bytes(len(ret)//8, "big")

def get_varint(data):
	"""Parse a protobuf varint out of the given data

	It's like a little-endian version of MIDI's variable-length
	integer. I don't know why Google couldn't just adopt what
	already existed.
	"""
	scale = ret = 0
	byte = 128
	while byte > 127:
		byte = data.get(1)[0]
		ret |= (byte&127) << scale
		scale += 7
	return ret

def build_varint(val):
	"""Build a protobuf varint for the given value"""
	data = []
	while val > 127:
		data.append((val & 127) | 128)
		val >>= 7
	data.append(val)
	return bytes(data)

# Handle protobuf wire types by destructively reading from data
protobuf_decoder = [get_varint] # Type 0 is varint
@protobuf_decoder.append
def protobuf_64bit(data):
	return data.get(8)
@protobuf_decoder.append
def protobuf_length_delimited(data):
	return data.get(get_varint(data))
@protobuf_decoder.append
def protobuf_start_group(data):
	raise Exception("Unimplemented")
@protobuf_decoder.append
def protobuf_end_group(data):
	raise Exception("Unimplemented")
@protobuf_decoder.append
def protobuf_32bit(data):
	return data.get(4)

int32, int64 = object(), object() # Pseudo-types. On decode they become normal integers.

class ProtoBuf:
	# These can be packed into arrays.
	PACKABLE = {int: get_varint, int32: protobuf_decoder[1], int64: protobuf_decoder[5]}

	@staticmethod
	def decode_value(val, typ, where):
		if isinstance(val, int): return val # Only for varints, which should always be ints
		assert isinstance(val, bytes)
		if isinstance(typ, type) and issubclass(typ, ProtoBuf): return typ.decode_protobuf(val)
		if typ in (int32, int64): return int.from_bytes(val, "little")
		if typ is float: return struct.unpack("<f", val) # TODO: Should this be subscripted [0]?
		if typ is str: return val.decode("UTF-8")
		if typ is bytes: return val
		if typ in (list, dict): return val # TODO
		raise ValueError("Unrecognized annotation %r in %s: data %r" % (typ, where, val[:64]))
	@classmethod
	def decode_protobuf(cls, data):
		fields = list(cls.__dataclass_fields__)
		data = Consumable(data)
		values = {}
		while data:
			idx, wiretype = divmod(get_varint(data), 8)
			field = fields[idx - 1]
			val = protobuf_decoder[wiretype](data)
			typ = cls.__dataclass_fields__[field].type
			if isinstance(typ, list):
				lst = values.setdefault(field, [])
				if typ[0] in cls.PACKABLE and wiretype == 2:
					# Packed integers.
					val = Consumable(val)
					while val:
						lst.append(cls.PACKABLE[typ[0]](val))
				else:
					lst.append(cls.decode_value(val, typ[0], cls.__name__ + "." + field))
			else:
				values[field] = cls.decode_value(val, typ, cls.__name__ + "." + field)
		return cls(**values)

	@staticmethod
	def encode_value(val, typ, where):
		if isinstance(val, int):
			if typ is int32: return val.to_bytes(4, "little")
			if typ is int64: return val.to_bytes(8, "little")
			return build_varint(val)
		if isinstance(val, bytes): return val # Stuff we can't decode gets returned untouched
		if hasattr(val, "encode_protobuf"): return val.encode_protobuf()
		if typ is str: return val.encode("UTF-8")
		if typ is float: return struct.pack("<f", val)
		if isinstance(typ, list) and typ[0] is int:
			# Packed integers (supporting varint only)
			return b"".join(build_varint(n) for n in val)
		raise ValueError("Unrecognized annotation %r in %s: data %r" % (typ, where, val))
	def encode_protobuf(self):
		data = []
		for idx, field in enumerate(self.__dataclass_fields__):
			val = getattr(self, field)
			if not val and val != 0: continue # Skip empties, except that a 0 int should still get encoded
			typ = self.__dataclass_fields__[field].type
			if typ is int:
				# Wiretype 0 integer
				data.append(build_varint(idx * 8 + 8))
				data.append(build_varint(val))
				continue
			if isinstance(typ, list) and typ[0] is not int:
				typ = typ[0]
				for val in val:
					val = self.encode_value(val, typ, self.__class__.__name__ + "." + field + "[*]")
					assert isinstance(val, bytes)
					data.append(build_varint(idx * 8 + 10))
					data.append(build_varint(len(val)))
					data.append(val)
				continue
			val = self.encode_value(val, typ, self.__class__.__name__ + "." + field)
			assert isinstance(val, bytes)
			data.append(build_varint(idx * 8 + 10))
			data.append(build_varint(len(val)))
			data.append(val)
		return b"".join(data)

# Stub types that are used by SaveFile
SkillData = ResourceData = ItemData = Weapon = MissionPlaythrough = bytes
DLCData = RegionGameStage = WorldDiscovery = WeaponMemento = ItemMemento = bytes
Challenge = OneOffChallenge = Lockout = VehicleSkin = bytes

@dataclass
class Color(ProtoBuf):
	alpha: int
	red: int
	green: int
	blue: int
	def __repr__(self): return "RGBA<%d,%d,%d,%d>" % (self.red, self.green, self.blue, self.alpha)
@dataclass
class UIPreferences(ProtoBuf):
	name: str
	color1: Color
	color2: Color
	color3: Color

@dataclass
class InventorySlots(ProtoBuf):
	backpack: int
	weapons: int
	num_quick_slots_flourished: int # No idea what this is.

@dataclass
class BankSlot(ProtoBuf):
	serial: bytes
	# Yes, that's all there is. Just a serial number. Packaged up in a protobuf.
	def prefix(self): return "Bank: "
	def order(self): return 8
	def is_equipped(self): return False
	def is_carried(self): return False

@dataclass
class PackedItemData(ProtoBuf):
	serial: bytes
	quantity: int
	equipped: int
	mark: int
	def prefix(self): return "Equipped: " if self.equipped else ""
	def order(self): return 5 if self.equipped else 6
	def is_equipped(self): return self.equipped
	def is_carried(self): return True

@dataclass
class PackedWeaponData(ProtoBuf):
	serial: bytes
	quickslot: int
	mark: int
	unknown4: int = None
	def prefix(self): return "Weapon %d: " % self.quickslot if self.quickslot else ""
	def order(self): return self.quickslot or 6
	def is_equipped(self): return self.quickslot
	def is_carried(self): return True

@dataclass
class SaveFile(ProtoBuf):
	playerclass: str
	level: int
	exp: int
	general_skill_points: int
	specialist_skill_points: int # No idea what the diff is btwn these
	money: [int] # [money, Eridium/Moonstones, Seraph tokens, unknown, Torgue tokens, then eight more unknowns]
	playthroughs_completed: int
	skills: [SkillData]
	unknown9: [int] = None
	unknown10: [int] = None
	resources: [ResourceData] = None
	items: [ItemData] = None
	inventory_slots: InventorySlots = None
	weapons: [Weapon] = None
	stats: bytes = b"" # ?? Opaque (for now)
	fasttravel: [str] = None
	last_fasttravel: str = ""
	missions: [MissionPlaythrough] = None
	preferences: UIPreferences = None
	savegameid: int = 0
	plotmission: int = 0
	unknown22: int = None
	codesused: [int] = None
	codes_needing_notifs: [int] = None
	total_play_time: int = 0
	last_save_date: str = ""
	dlc: [DLCData] = None
	unknown28: [str] = None
	region_game_stages: [RegionGameStage] = None
	world_discovery: [WorldDiscovery] = None
	badass_mode: int = 0
	weapon_mementos: [WeaponMemento] = None
	item_mementos: [ItemMemento] = None
	save_guid: bytes = b""
	applied_customizations: [str] = None # Current skins?
	black_market: [int] = None
	active_mission: int = 0
	challenges: [Challenge] = None
	level_challenge_unlocks: [int] = None
	one_off_level_challenges: [OneOffChallenge] = None
	bank: [BankSlot] = None
	challenge_prestiges: int = 0
	lockout_list: [Lockout] = None
	is_dlc_class: int = None
	dlc_class_package: int = None
	fully_explored: [str] = None
	unknown47: [bytes] = None
	golden_keys: int = 0 # Number "notified", whatever that means.
	last_playthrough: int = 0
	show_new_playthrough_notif: int = 0
	rcvd_default_weap: int = 0
	queued_training_msgs: [str] = None
	packed_item_data: [PackedItemData] = None
	packed_weapon_data: [PackedWeaponData] = None
	awesome_skill_disabled: int = 0
	max_bank_slots: int = 0 # Might be useful when looking for a place to put stuff
	vehicle_skins: [VehicleSkin] = None
	if GAME == "borderlands the pre-sequel":
		body_switches: bytes = b""
		player_flags: [int] = None
		vehicle_steering_mode: int = 0
		discovered_compass_icons: [bytes] = None
		suppress_oxygen_notifs: int = 0
	else:
		vehicle_steering_mode: int = 0
	has_played_uvhm: int = None
	overpower_levels: int = None
	last_overpower_choice: int = None

	def add_inventory(self, asset):
		if asset.is_weapon:
			packed = PackedWeaponData(serial=asset.encode_asset_library(), quickslot=0, mark=1, unknown4=0)
			self.packed_weapon_data.append(packed)
		else:
			packed = PackedItemData(serial=asset.encode_asset_library(), quantity=1, equipped=0, mark=1)
			self.packed_item_data.append(packed)

class SaveFileFormatError(Exception): pass

def parse_savefile(fn):
	with open(fn, "rb") as f: data = Consumable(f.read())
	# PC builds, presumably including Linux builds, should be
	# little-endian and LZO-compressed. Some retrievals are
	# forced big-endian, others vary by platform. Dunno why.
	endian = "little"
	hash = data.get(20)
	if hash != hashlib.sha1(data.peek()).digest():
		raise SaveFileFormatError("Hash fails to validate")
	uncompressed_size = int.from_bytes(data.get(4), "big")
	if uncompressed_size > 0x40000:
		raise SaveFileFormatError("TODO: handle chunked decompression")
	raw = lzo.decompress(data.peek(), False, uncompressed_size)
	if len(raw) != uncompressed_size:
		raise SaveFileFormatError("Got wrong amount of data back (%d != %d)" % (len(raw), uncompressed_size))
	if args.verify:
		# LZO compression isn't stable or consistent enough to compare the
		# compressed bytes to what we got from the file. But let's just
		# quickly make sure we can get something back, at least.
		comp = lzo.compress(raw, 1, False)
		if lzo.decompress(comp, False, uncompressed_size) != raw:
			print("Recompression gives something that we didn't get first time!")
			return ""
	# Okay. Decompression complete. Now to parse the actual data.
	data = Consumable(raw)
	size = int.from_bytes(data.get(4), "big")
	if size != len(data):
		raise SaveFileFormatError("Size doesn't match remaining bytes - corrupt file? chunked?");
	if data.get(3) != b"WSG":
		raise SaveFileFormatError("Invalid magic number - corrupt file?")
	if int.from_bytes(data.get(4), endian) != 2:
		raise SaveFileFormatError("Unsupported version number (probable corrupt file)")
	crc = int.from_bytes(data.get(4), endian)
	uncomp_size = int.from_bytes(data.get(4), endian) # Gibbed uses a *signed* 32-bit int here
	# For some bizarre reason, the data in here is Huffman-compressed.
	# The whole file has already been LZO-compressed. No point compressing twice!
	# Not sure what the last four bytes are. The end of the compressed sequence
	# finishes off the current byte, and then there are always four more bytes.
	if data.peek()[-4:] != b"\xd4\x93\x9f\x1a":
		raise SaveFileFormatError("Different last four bytes: %r" % data.peek()[-4:])
	data = huffman_decode(data.peek()[:-4], uncomp_size)
	if crc != binascii.crc32(data):
		raise SaveFileFormatError("CRC doesn't match (%d vs %d)" % (crc, binascii.crc32(data)))
	if args.verify:
		reconstructed = huffman_encode(data)
		reconstructed = b"".join([
			(3 + 4 + 4 + 4 + len(reconstructed) + 4).to_bytes(4, "big"),
			b"WSG",
			(2).to_bytes(4, endian),
			binascii.crc32(data).to_bytes(4, endian),
			len(data).to_bytes(4, endian),
			reconstructed,
			b"\xd4\x93\x9f\x1a",
		])
		if reconstructed != raw:
			if len(reconstructed) != len(raw):
				print("Imperfect recompression:", len(raw), len(reconstructed))
				return ""
			print("Mismatched after recompression", len(raw))
			for ofs in range(0, len(raw), 64):
				old = raw[ofs:ofs+64]
				new = reconstructed[ofs:ofs+64]
				if old != new:
					print(ofs, old)
					print(ofs, new)
			return ""
	savefile = SaveFile.decode_protobuf(data)
	if args.verify:
		reconstructed = savefile.encode_protobuf()
		if reconstructed != data:
			print("Imperfect reconstruction:", len(data))
			for sz in range(64, max(len(data), len(reconstructed))+65, 64):
				if data[:sz] == reconstructed[:sz]: continue
				print(sz-64)
				print(data[sz-64:sz])
				print(reconstructed[sz-64:sz])
				break
			return ""
	cls = get_asset("Player Classes")[savefile.playerclass]["class"]
	# The packed_weapon_data and packed_item_data arrays contain the correct
	# number of elements for the inventory items. (Equipped or backpack is
	# irrelevant, but anything that isn't a weapon ('nade mod, class mod, etc)
	# goes in the item data array.)
	items = []
	for item in (savefile.packed_weapon_data or []) + (savefile.packed_item_data or []) + (savefile.bank or []):
		if args.loot_filter is None: break
		it = Asset.decode_asset_library(item.serial)
		if not it: continue
		for filter, filterargs in args.loot_filter:
			if not filter(item, it, *filterargs): break
		else:
			items.append((item.order(), -it.grade, item.prefix() + repr(it)))
	ret = "Level %d (%dxp) %s: \x1b[1;31m%s\x1b[0m (%d+%d items)" % (savefile.level, savefile.exp, cls,
		savefile.preferences.name, len(savefile.packed_weapon_data), len(savefile.packed_item_data) - 2)
	items.sort()
	ret += "".join("\n" + desc for order, lvl, desc in items if order >= 0)
	if args.synth is not None:
		# Make changes to the save file before synthesizing
		# savefile.preferences.name = "PATCHED" # Easy way to see what's happening
		for synth, synthargs in args.synth: synth(savefile, *synthargs)

		data = savefile.encode_protobuf()
		reconstructed = huffman_encode(data)
		reconstructed = b"".join([
			(3 + 4 + 4 + 4 + len(reconstructed) + 4).to_bytes(4, "big"),
			b"WSG",
			(2).to_bytes(4, endian),
			binascii.crc32(data).to_bytes(4, endian),
			len(data).to_bytes(4, endian),
			reconstructed,
			b"\xd4\x93\x9f\x1a",
		])
		comp = len(reconstructed).to_bytes(4, "big") + lzo.compress(reconstructed, 1, False)
		comp = hashlib.sha1(comp).digest() + comp
		# TODO: Have an option to move the original into the current directory, and then write to the original file name
		with open("synthesized-%s.sav" % (args.file or ""), "wb") as f: f.write(comp)
	return ret

def compare(id1, id2):
	obj1, obj2 = [Asset.decode_asset_library(unarmor_serial(id)) for id in (id1, id2)]
	if obj1.is_weapon != obj2.is_weapon:
		print("Can only compare two weapons or two items, not one of each")
		return
	# Show the available options and which one is in each object
	# This is most often going to be used for comparing two items of the same
	# type/balance, so their piece options will be the same. But it can also
	# be used to compare two different ones, and see which part options change.
	# For each object, see if the part is Selected, Available, or Unavailable
	# (Note that None counts as a part.)
	colors = {
		"SS": "1", "AA": "0",
		"SA": "1;34", "AS": "1;32",
		"AU": "34", "UA": "32",
		"SU": "1;4;34", "US": "1;4;32",
	}
	print("\x1b[%sm%r\x1b[0m" % (colors["SA"], obj1))
	pieces1 = get_piece_options(obj1)
	print("\x1b[%sm%r\x1b[0m" % (colors["AS"], obj2))
	pieces2 = get_piece_options(obj2)
	for i, (n, opts1, opts2) in enumerate(zip(obj1.partnames, pieces1, pieces2)):
		seen = {}
		for p in opts1 + opts2 + [None]:
			if p in seen: continue # Deduplicate but keep order
			seen[p] = 1
			s1 = "A" if p in opts1 else "U"
			s2 = "A" if p in opts2 else "U"
			p1 = obj1.pieces[i]; p2 = obj2.pieces[i]
			if (p is None and not p1) or (p and p1 and p.endswith(p1)): s1 = "S"
			if (p is None and not p2) or (p and p2 and p.endswith(p2)): s2 = "S"
			state = s1 + s2
			if state == "UU": continue # Not available on either (probably "None"). Ignore it.
			print("%s \x1b[%sm%s\x1b[0m" % (n, colors[state], p))
			n = " " * len(n)

if args.compare:
	compare(*args.compare)
	sys.exit()
if args.platform == "native":
	dir = os.path.expanduser("~/.local/share/aspyr-media/" + GAME + "/willowgame/savedata")
else:
	appid = "261640" if GAME == "borderlands the pre-sequel" else "49520"
	dir = os.path.expanduser("~/.steam/steam/steamapps/compatdata/" + appid +
		"/pfx/drive_c/users/steamuser/My Documents/My Games/Borderlands 2/WillowGame/SaveData")
if args.player == "list":
	print("Player IDs available:")
	for player in sorted(os.listdir(dir)):
		print("--player", player)
	sys.exit(0)
if args.file:
	try: os.stat(args.file)
	except FileNotFoundError: pass
	else:
		try: print(parse_savefile(args.file))
		except SaveFileFormatError as e: print(e.args[0])
		sys.exit(0)
dir = args.dir or os.path.join(dir, args.player or os.listdir(dir)[0]) # If this bombs, you might not have any saves
file = (args.file or "").replace(".sav", "")
for fn in sorted(os.listdir(dir)):
	if not fn.endswith(".sav"): continue
	if not fnmatch(fn, "*" + file + ".sav"): continue
	print(fn, end="... ")
	try: print(parse_savefile(os.path.join(dir, fn)))
	except SaveFileFormatError as e: print(e.args[0])
if file == "synth":
	try: print(parse_savefile("synthesized.sav"))
	except SaveFileFormatError as e: print(e.args[0])
if args.library:
	if args.library == "input": lib = iter(input, "")
	else: lib = args.library.split(",")
	for id in lib:
		if '{' in id: id = id.split("{")[1].split("}")[0]
		if not id: continue
		serial = base64.b64decode(id.encode("ascii") + b"====")
		obj = Asset.decode_asset_library(serial)
		obj.grade = obj.stage = obj.seed = 50
		serial = obj.encode_asset_library()
		id = base64.b64encode(serial).decode("ascii").strip("=")
		if id not in library[args.game]:
			print('\t\t"%s": "%s",' % (id, obj.get_title()))
