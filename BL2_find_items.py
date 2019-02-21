# Parse Borderlands 2 savefiles and list all items across all characters
# See https://github.com/gibbed/Gibbed.Borderlands2 for a Windows-only
# program to do way more than this, including actually changing stuff.
# This is much simpler; its purpose is to help you twink items between
# your characters, or more specifically, to find the items that you want
# to twink. It should be able to handle Windows and Linux save files, but
# not save files from consoles (they may be big-endian, and/or use another
# compression algorithm). Currently the path is hard-coded for Linux though.
import binascii
import hashlib
import json
import os.path
import struct
from dataclasses import dataclass
from pprint import pprint
import lzo # ImportError? pip install python-lzo

# GAME = "borderlands 2"
GAME = "borderlands the pre-sequel"

# Requires access to the Gibbed data files.
ASSET_PATH = "../GibbedBL2/Gibbed.Borderlands%s/projects/Gibbed.Borderlands%s.GameInfo/Resources/%s.json"
def get_asset(fn, cache={}):
	if fn not in cache:
		if GAME == "borderlands 2": path = ASSET_PATH % ("2", "2", fn)
		else: path = ASSET_PATH % ("Oz", "Oz", fn)
		with open(path, "rb") as f: cache[fn] = json.load(f)
	return cache[fn]

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
	def __len__(self): return self.left
	def peek(self): return self.data[self.eaten:] # Doubles as "convert to bytes/str"
	@classmethod
	def from_bits(cls, data):
		"""Create a bitfield consumable from packed eight-bit data"""
		return cls(''.join(format(x, "08b") for x in data))
class ConsumableLE(Consumable):
	"""Little-endian bitwise consumable"""
	def get(self, num):
		return super().get(num)[::-1]
	@classmethod
	def from_bits(cls, data):
		"""Create a bitfield consumable from packed eight-bit data"""
		return cls(''.join(format(x, "08b")[::-1] for x in data))

def bogodecrypt(seed, data):
	if not seed: return data
	if seed > 1<<31: seed |= 31<<32 # Emulate an arithmetic right shift
	xor = seed >> 5
	data = list(data)
	for i, x in enumerate(data):
		# ??? No idea. Got this straight from Gibbed.
		xor = (xor * 0x10A860C1) % 0xFFFFFFFB
		data[i] = x ^ (xor & 255)
	data = bytes(data)
	split = len(data) - ((seed % 32) % len(data))
	return data[split:] + data[:split]

# Many entries in the files are of the form "GD_Weap_SniperRifles.A_Weapons.WeaponType_Vladof_Sniper"
# but the savefile just has "A_Weapons.WeaponType_Vladof_Sniper". The same prefix appears to be used
# for the components of the weapon. So far, I have not figured out how to synthesize the prefix, but
# for any given type, there is only one prefix, so we just calculate from that.
def _category(type_or_bal, _cache = {}):
	if _cache: return _cache[type_or_bal]
	for lbl in list(get_asset("Item Types")) + list(get_asset("Weapon Types")) \
			+ list(get_asset("Item Balance")) + list(get_asset("Weapon Balance")):
		cat, lbl = lbl.split(".", 1)
		if lbl in _cache:
			print("DUPLICATE:")
			print(_cache[lbl] + "." + lbl)
			print(cat + "." + lbl)
		_cache[lbl] = cat
	return _cache[type_or_bal]

def decode_asset_library(data):
	seed = int.from_bytes(data[1:5], "big")
	data = data[:5] + bogodecrypt(seed, data[5:])
	data += b"\xFF" * (40 - len(data)) # Pad to 40 with 0xFF
	crc16 = int.from_bytes(data[5:7], "big")
	data = data[:5] + b"\xFF\xFF" + data[7:]
	crc = binascii.crc32(data)
	crc = (crc >> 16) ^ (crc & 65535)
	if crc != crc16: raise ValueError("Checksum mismatch")
	config = get_asset("Asset Library Manager")
	if "sets_by_id" not in config:
		# Remap the sets to be keyed by ID - it's more useful that way.
		config["sets_by_id"] = {set["id"]: set for set in config["sets"]}
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
		cfg = config["sets_by_id"][setid if useset == "1" else 0]["libraries"][field]
		# print(field, cfg["sublibraries"][int(sublib,2)]["assets"][int(asset,2)])
		return cfg["sublibraries"][int(sublib,2)]["assets"][int(asset,2)]

	type = _decode(weap_item + "Types")
	balance = _decode("BalanceDefs")
	brand = _decode("Manufacturers")
	# There are two fields, "Grade" and "Stage". Not sure what the diff
	# is, as they seem to be equal.
	grade = int(bits.get(7), 2)
	stage = int(bits.get(7), 2)
	if grade == stage: lvl = "Lvl %d" % grade
	else: lvl = "Level %d/%d" % (grade, stage)
	if is_weapon:
		parts = "body grip barrel sight stock elemental acc1 acc2"
	else:
		parts = "alpha beta gamma delta epsilon zeta eta theta"
	for part in parts.split():
		_decode(weap_item + "Parts")
	material = _decode(weap_item + "Parts")
	pfx = _decode(weap_item + "Parts") or "<no pfx>"
	title = _decode(weap_item + "Parts") or "<no title>"
	names = get_asset(weap_item + " Name Parts")
	for cat in (_category(type), _category(balance), "GD_Weap_Shared_Names"):
		pfxinfo = names.get(cat + "." + pfx)
		if pfxinfo: break
	# pfxinfo has a name (unless it's a null prefix), and a uniqueness flag. No idea what that one is for.
	for cat in (_category(type), _category(balance), "GD_Weap_Shared_Names"):
		titinfo = names.get(cat + "." + title)
		if titinfo: break
	if titinfo: title = titinfo["name"]
	if pfxinfo and "name" in pfxinfo: title = pfxinfo["name"] + " " + title
	type = type.split(".", 1)[1].replace("WT_", "").replace("WeaponType_", "").replace("_", " ")
	return "%s %s (%s)" % (lvl, title, type)

def decode_tree(bits):
	"""Decode a (sub)tree from the given sequence of bits

	Returns either a length-one bytes, or a tuple of two trees (left
	and right). Consumes either a 1 bit and then eight data bits, or
	a 0 bit and then two subtrees.
	"""
	if bits.get(1) == "1": # Is it a leaf?
		return bytes([int(bits.get(8), 2)])
	# Otherwise, it has subnodes.
	return (decode_tree(bits), decode_tree(bits))
def huffman_decode(data, size):
	bits = Consumable.from_bits(data)
	root = decode_tree(bits)
	ret = []
	while len(ret) < size:
		cur = root
		while isinstance(cur, tuple):
			cur = cur[bits.get(1) == "1"]
		ret.append(cur)
	residue = bits.peek()
	if len(residue) >= 8: raise ValueError("Too much compressed data - residue " + residue)
	return b''.join(ret)

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

@dataclass
class PackedItemData(ProtoBuf):
	serial: bytes
	quantity: int
	equipped: int
	mark: int

@dataclass
class PackedWeaponData(ProtoBuf):
	serial: bytes
	quickslot: int
	mark: int
	unknown4: int = None

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
	data = Consumable(lzo.decompress(data.peek(), False, uncompressed_size))
	if len(data) != uncompressed_size:
		raise SaveFileFormatError("Got wrong amount of data back (%d != %d)" % (len(data), uncompressed_size))
	# Okay. Decompression complete. Now to parse the actual data.
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
	data = huffman_decode(data.peek()[:-4], uncomp_size)
	savefile = SaveFile.decode_protobuf(data)
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
	# goes in the item data array.
	print()
	for weapon in savefile.packed_weapon_data:
		if weapon.quickslot: print("Weapon #%d:" % weapon.quickslot, end=" ")
		print(decode_asset_library(weapon.serial))
	for item in savefile.packed_item_data:
		it = decode_asset_library(item.serial)
		if not it: continue
		print(("Equipped: " if item.equipped else "") + it)
	for item in savefile.bank or []:
		print("Bank:", decode_asset_library(item.serial))
	return "Level %d %s: %s (%d+%d items)" % (savefile.level, cls,
		savefile.preferences.name, len(savefile.packed_weapon_data), len(savefile.packed_item_data) - 2)

dir = os.path.expanduser("~/.local/share/aspyr-media/" + GAME + "/willowgame/savedata")
dir = os.path.join(dir, os.listdir(dir)[0]) # If this bombs, you might not have any saves
for fn in sorted(os.listdir(dir)):
	if not fn.endswith(".sav"): continue
	# if fn != "save000a.sav": continue # Hack: Use the smallest file available
	print(fn, end="... ")
	try: print(parse_savefile(os.path.join(dir, fn)))
	except SaveFileFormatError as e: print(e.args[0])
