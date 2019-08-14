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
	if typ is str:
		return data.str()
	if typ is float:
		return struct.unpack("f", data.get(4))[0]
	raise TypeError("need to implement: %r %r" % (type(type), typ))

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
class Savefile:
	sig: b"WSG"
	ver: b"\2\0\0\0"
	type: 4
	unknown1: 4
	cls: str
	level: int
	unknown2: 4
	zeroes1: bytes(8)
	unknown3: 8
	skills: [Skill]
	zeroes2: bytes(8)
	unknown4: int
	zeroes3: bytes(4)
	ammo: [Ammo]

def parse_savefile(fn):
	with open(fn, "rb") as f: data = Consumable(f.read())
	savefile = decode_dataclass(data, Savefile)
	# Items
	for _ in range(data.int()):
		grade = data.str()
		balance = data.str()
		pieces = [data.str() for _ in range(4)]
		mfg = data.str()
		prefix = data.str()
		title = data.str()
		values = [data.int() for _ in range(5)]
		# values[2] seems to be 1 if equipped, 0 if not
		# Can't find item level though
		# print(grade.split(".")[-1], mfg.split(".")[-1], values)
	unknowns = data.int(), data.int()
	# print("-- Unknowns between items and weapons:", unknowns)
	# Weapons
	for _ in range(data.int()):
		grade = data.str()
		mfg = data.str()
		type = data.str()
		pieces = [data.str() for _ in range(8)]
		material = data.str()
		prefix = data.str()
		title = data.str()
		values = [data.int() for _ in range(5)]
		# values[2] seems to be 1-4 if equipped, 0 if not
		# Still can't find item level
		# print(grade.split(".")[-1], mfg.split(".")[-1], values)
	unknown = data.hollerith() # always 1347 bytes long, unknown meaning
	fasttravels = [data.str() for _ in range(data.int())] # Doesn't include DLCs that have yet to be tagged up
	last_location = data.str() # You'll spawn at this location
	assert last_location in fasttravels
	zeroes = data.get(12)
	unknown = data.int()
	zero = data.int()
	unknowns = [data.int() for _ in range(5)] # [1-4, 39, ??, 3, 0] where the middle one is higher on more-experienced players
	current_mission = data.str() # I think? Maybe?
	for _ in range(data.int()):
		mission = data.str()
		# print(mission)
		unknowns = data.int(), data.int(), data.int() # Always 4, 0, 0 for done missions, I think? Maybe a status or something.
		goals = [(data.str(), data.int()) for _ in range(data.int())] # Always 0 of these for done missions
	for _ in range(2): unknown = data.int(), data.str() # More missions???
	unknown = [data.int() for _ in range(4)]
	for _ in range(2): unknown = data.int(), data.str() # More missions???
	unknown = [data.int() for _ in range(5)]
	timestamp = data.str() # Last saved? I think?
	name = data.str(); print("%s (%s)" % (name, savefile.cls.split("_")[-1]))
	colours = data.int(), data.int(), data.int()
	unknown = data.get(0x69)
	for _ in range(data.int()):
		echo = data.str();
		unknown = (data.int(), data.int())
	while data.int() != 0x43211234: pass # Unknown values - more of them if you've finished the game??
	unknown = data.get(59)
	# Bank weapons maybe?? It's possible the last four bytes of the previous 'unknown' is number of bank items.
	for _ in range(data.int()):
		item = [data.str() for _ in range(14)]
		values = [data.int() for _ in range(5)]
	# print(struct.unpack("f", data.get(4))[0])
	unknown = [data.int() for _ in range(6)]
	print(", ".join(hex(x) for x in unknown))
	zeroes = data.get(80)
	assert zeroes == bytes(80)
	assert len(data) == 0
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
