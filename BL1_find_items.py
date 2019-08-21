import os.path
import struct
from dataclasses import dataclass # ImportError? Upgrade to Python 3.7 or pip install dataclasses

class Consumable:
	"""Like a bytes/str object but can be consumed a few bytes/chars at a time"""
	def __init__(self, data):
		self.data = data
		self.eaten = 0
		self.left = len(data)
	def get(self, num):
		"""Destructively read the next num bytes/chars of data"""
		if num > self.left: raise ValueError("Out of data!")
		ret = self.data[self.eaten : self.eaten + num]
		self.eaten += num
		self.left -= num
		return ret
	def int(self, size=4, order="little"): return int.from_bytes(self.get(size), order)
	def hollerith(self, size=4, order="little"): return self.get(self.int(size, order))
	def str(self): return self.hollerith().rstrip(b"\x00").decode("ascii")
	def __len__(self): return self.left
	def peek(self): return self.data[self.eaten:] # Doubles as "convert to bytes/str"
	@classmethod
	def from_bits(cls, data):
		"""Create a bitfield consumable from packed eight-bit data"""
		return cls(''.join(format(x, "08b") for x in data))

class SaveFileFormatError(Exception): pass

def decode_dataclass(data, typ):
	if hasattr(typ, "__dataclass_fields__"):
		values = {}
		for field in typ.__dataclass_fields__.values():
			values[field.name] = decode_dataclass(data, field.type)
		return typ(**values)
	if isinstance(typ, list):
		if len(typ) == 2:
			# Hack because I have no idea what's going on here
			# Decode up to a sentinel
			ret = [decode_dataclass(data, typ[0])]
			while ret[-1] != typ[1]: ret.append(decode_dataclass(data, typ[0]))
			return ret
		return [decode_dataclass(data, typ[0]) for _ in range(data.int())]
	if isinstance(typ, tuple):
		return tuple(decode_dataclass(data, t) for t in typ)
	if isinstance(typ, int):
		return data.get(typ)
	if isinstance(typ, bytes):
		ret = data.get(len(typ))
		assert ret == typ
		return ret
	if typ is int:
		return data.int()
	if isinstance(typ, range):
		# Bounded integer
		l = len(typ)
		ret = data.int(1 if l <= 256 else 2 if l <= 65536 else 4)
		# TODO: Support signed numbers eg range(-128, 127)
		assert ret in typ
		return ret
	if typ is bytes:
		return data.hollerith()
	if typ is str:
		return data.str()
	if typ is float:
		return struct.unpack("f", data.get(4))[0]
	if typ is print:
		print(data.peek()[:16], len(data))
		return None
	raise TypeError("need to implement: %r %r" % (type(typ), typ))

def encode_dataclass(data, typ):
	if hasattr(typ, "__dataclass_fields__"):
		ret = []
		for field in typ.__dataclass_fields__.values():
			ret.append(encode_dataclass(getattr(data, field.name), field.type))
		return b"".join(ret)
	if isinstance(typ, list):
		if len(typ) == 2:
			# Hack, as above
			# Decode up to a sentinel
			assert data[-1] == typ[1]
			return b"".join(encode_dataclass(val, typ[0]) for val in data)
		return encode_dataclass(len(data), int) + b"".join(encode_dataclass(val, typ[0]) for val in data)
	if isinstance(typ, tuple):
		return b"".join(encode_dataclass(val, t) for val, t in zip(data, typ))
	if isinstance(typ, int):
		assert len(data) == typ
		return data
	if isinstance(typ, bytes):
		assert data == typ
		return data
	if typ is int:
		return data.to_bytes(4, "little")
	if isinstance(typ, range):
		# Bounded integer
		l = len(typ)
		assert data in typ
		# TODO as above, signed integers
		return data.to_bytes(1 if l <= 256 else 2 if l <= 65536 else 4, "little")
	if typ is bytes:
		return encode_dataclass(len(data), int) + data
	if typ is str:
		return encode_dataclass(data.encode("ascii") + b"\x00", bytes)
	if typ is float:
		return struct.pack("f", data)
	if typ is print:
		return b""
	raise TypeError("need to implement: %r %r" % (type(type), typ))

# For anyone reading this file to try to understand the save file format:
# Firstly, be sure to also read the WillowTree# source code, which is more
# comprehensive but less comprehensible than this - you can find it at
# http://willowtree.sourceforge.net. Everything in here came either from my
# own explorations with a hex editor or from reading the WillowTree# source.
# Secondly, these classes represent different structures within the file;
# fields are laid out sequentially with no padding.
# Annotation	Meaning
# int		32-bit unsigned integer
# float		32-bit IEEE binary floating-point
# bytes		Hollerith byte string consisting of a 32-bit length followed
#		by that many bytes of raw data
# str		Hollerith text string: 32-bit length, that many bytes of ASCII
#		data, then b"\0" (included in the length)
# b"..."	Exactly those bytes. Used for signatures etc.
# range(N)	Integer within the given range, taking up the minimum space
#		(so a range(65536) is a 16-bit integer)
# AnyClassName	One instance of the named class (potentially recursive)
# (x,y,z)	The given values in that exact order. Identical in the file to
#		having the same three annotations separately identified.
# [x]		Hollerith array: 32-bit length, then that many instances of
#		whatever is in the list (so [int] would make an array of ints).
# [x, marker]	HACK. Reads type x until it matches the marker. :(

@dataclass
class Skill:
	name: str
	level: int
	progress: int # Possibly progress to next level?? Applies only to proficiencies.
	state: int # Always either -1 or 1

@dataclass
class Ammo:
	cat: str
	pool: str
	amount: float # WHY??? Ammo regen maybe???
	capacity: int # 0 = base capacity, 1 = first upgrade, etc

@dataclass
class Item: # Can't find item level
	grade: str
	type: str
	pieces: (str,) * 4
	mfg: str
	prefix: str
	title: str
	unknown: int
	quality: range(65536)
	level: range(65536)
	slot: int # 1 if equipped or 0 for backpack
	junk: int
	locked: int

@dataclass
class Weapon:
	grade: str
	mfg: str
	type: str
	pieces: (str,) * 8
	material: str
	prefix: str
	title: str
	ammo: int
	quality: range(65536)
	level: range(65536)
	slot: int # 1-4 or 0 for backpack
	junk: int
	locked: int

@dataclass
class BankItem: # Bank items have things in a different order. Weird.
	type: str
	grade: str
	mfg: str
	pieces: (str,) * 4
	prefix: str
	title: str

@dataclass
class Mission:
	mission: str
	progress: int # 4 for done missions
	unknown: (int, int)
	goals: [(str, int)] # Always 0 of these for done missions

@dataclass
class MissionBlock:
	id: int # Sequentially numbered blocks
	current_mission: str # I think? Maybe?
	missions: [Mission]

@dataclass
class Challenges:
	outer_length: b"\x43\x05\0\0" # Length of this entire structure (not counting itself)
	id: b"\3\0\0\0"
	inner_length: b"\x3b\x05\0\0" # Length of the rest of the structure. Yes, exactly 8 less than outer_length.
	@dataclass
	class Challenge:
		id: range(65536)
		type: range(256) # Either 1 or 5, usually 1
		value: int
	count: b"\xbf\0" # Number of entries - it's 16-bit but otherwise same as saying [Challenge]
	challenges: (Challenge,) * 191

@dataclass
class Savefile:
	sig: b"WSG" # If it's not, this might be an Xbox save file
	ver: b"\2\0\0\0" # If it's not, this might be a big-endian PS3 save file
	type: b"PLYR"
	revision: int
	cls: str
	level: int
	xp: int
	zeroes1: bytes(8)
	money: int
	finished_once: int # 1 if you've finished the first playthrough
	skills: [Skill]
	vehicle_info: (int,) * 4 # Vehicle info
	ammo: [Ammo]
	items: [Item]
	backpacksize: int
	weaponslots: int
	weapons: [Weapon]
	challenges: Challenges
	fasttravels: [str] # Doesn't include DLCs that have yet to be tagged up
	last_location: str # You'll spawn at this location
	zeroes4: bytes(12)
	unknown7: int
	zeroes5: bytes(4)
	savefile_index: int # Possibly needs to correspond to the file name??
	unknown8: b"\x27\0\0\0"
	unknown8a: int # Higher on more-experienced players, up to 45 on completion of main plot
	missions: [MissionBlock]
	playtime: int
	timestamp: str # Last saved? I think?
	name: str
	colours: (int, int, int)
	enhancedblock: 0x55 # ???
	unknown10: int
	promocodes: [int]
	promocodes_new: [int]
	unknown10a: 8
	echo_recordings: [(str, int, int)] # No idea what the ints mean, probably flags about having heard them or something
	unknown11: [int, 0x43211234] # Unknown values - more of them if you've finished the game??
	unknown12: 9
	bank_weapons: [(14, str, str, str, 13, str, str, str, 13, str, str, str, 3, print)]
	unknown13: 42
	dlc_items: [Item] # DLC-only items??
	dlc_weapons: [Weapon] # Ditto
	unknown99: (int,) * 6
	zeroes6: bytes(80)

def parse_savefile(fn):
	with open(fn, "rb") as f: data = Consumable(f.read())
	savefile = decode_dataclass(data, Savefile)
	assert savefile.last_location in savefile.fasttravels
	print("%s (level %d %s, $%d)" % (savefile.name, savefile.level, savefile.cls.split("_")[-1], savefile.money))
	for weapon in sorted(savefile.weapons + savefile.dlc_weapons, key=lambda w: w.slot or 5):
		print("%d: [%d-%d] %s %s" % (weapon.slot, weapon.level, weapon.quality, weapon.prefix.split(".")[-1], weapon.title.split(".")[-1]))
	for item in sorted(savefile.items + savefile.dlc_items, key=lambda w: w.slot or 5):
		print("%d: [%d-%d] %s %s" % (item.slot, item.level, item.quality, item.prefix.split(".")[-1], item.title.split(".")[-1]))
	# print(", ".join(hex(x) for x in savefile.unknown13))
	# print(*savefile.bank_weapons, sep="\n")
	assert len(data) == 0
	assert encode_dataclass(savefile, Savefile) == data.data
	if 0:
		savefile.name = "PATCHED"
		for ammo in savefile.ammo:
			if ammo.amount > 10: ammo.amount -= 1.0
		newweaps = []
		for weapon in savefile.weapons:
			if weapon.slot:
				for quality in range(weapon.quality, 6):
					newweap = Weapon(**vars(weapon))
					newweap.quality = quality
					newweap.slot = 0
					# print(newweap)
					newweaps.append(newweap)
		savefile.weapons.extend(newweaps) # Don't change the list while we're iterating over it
		synthesized = encode_dataclass(savefile, Savefile)
		with open(os.path.basename(fn), "wb") as f: f.write(synthesized)
	return ""

dir = os.path.expanduser("~/.steam/steam/steamapps/compatdata/729040/pfx/drive_c/users/steamuser/My Documents/My Games/Borderlands Game of the Year/Binaries/SaveData")
for fn in sorted(os.listdir(dir)):
	if not fn.endswith(".sav"): continue
	print(fn, end="... ")
	try: print(parse_savefile(os.path.join(dir, fn)))
	except SaveFileFormatError as e: print(e.args[0])
	print()

''' Gear
1: 32 Volcano - Maliwan sniper
2: 20 Hellfire - Maliwan SMG
3: 37 Eridian Lightning
4: 36 Torgue launcher
-: 34 Maliwan SMG
-: 33 Hyperion Repeater
-: 28 Eridian Cannon
e: 34 Pangolin shield
e: 31 Anshin transfusion grenade
e: 16 Dahl class mod, Mercenary
-: 31 Tediore shield

Money 1102561 0x10d2e1 or float \x08\x97\x86\x49
'''

# 000020c5 43 05
# 0000260c 32 00 00 00
