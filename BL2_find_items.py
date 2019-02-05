# Parse Borderlands 2 savefiles and list all items across all characters
# See https://github.com/gibbed/Gibbed.Borderlands2 for a Windows-only
# program to do way more than this, including actually changing stuff.
# This is much simpler; its purpose is to help you twink items between
# your characters, or more specifically, to find the items that you want
# to twink. It should be able to handle Windows and Linux save files, but
# not save files from consoles (they may be big-endian, and/or use another
# compression algorithm). Currently the path is hard-coded for Linux though.
import hashlib
import os.path
import struct
from dataclasses import dataclass
from pprint import pprint
import lzo # ImportError? pip install python-lzo

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
	bits = Consumable(''.join(format(x, "08b") for x in data))
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

class ProtoBuf:
	@staticmethod
	def decode_value(val, typ):
		if isinstance(val, int): return val # Only for varints, which should always be ints
		assert isinstance(val, bytes)
		if isinstance(typ, type) and issubclass(typ, ProtoBuf): return typ.decode_protobuf(val)
		if typ is int: return int.from_bytes(val, "little")
		if typ is float: return struct.unpack("<f", val)
		if typ is str: return val #.decode("UTF-8") # enable once every str really means str
		if typ is bytes: return val
		if typ in (list, dict): return val # TODO
		raise ValueError("Unrecognized annotation %r" % typ)
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
				lst.append(cls.decode_value(val, typ[0]))
			else:
				values[field] = cls.decode_value(val, typ)
			if isinstance(val, (str, bytes)) and len(val) > 30: val = val[:30]
			print("%d: Setting %s to %s" % (idx, field, values[field]))
		return cls(**values)

@dataclass
class SaveFile(ProtoBuf):
	playerclass: str = ""
	level: int = 0
	exp: int = 0
	general_skill_points: int = 0
	specialist_skill_points: int = 0 # No idea what the diff is btwn these
	money: list = None # TODO: Packed list
	playthroughs_completed: int = 0
	skills: list = None # TODO: Repeatable, each is packed data
	unknown9: list = None
	unknown10: list = None
	resources: list = None # TODO: Repeatable, each is packed data
	items: list = None # TODO: Packed?
	inventory: list = None # TODO: Packed?
	weapons: list = None # TODO: Packed?
	stats: list = None # TODO
	fasttravel: list = None # TODO
	last_fasttravel: str = ""
	missions: list = None
	preferences: dict = None
	savegameid: int = 0
	plotmission: int = 0
	unknown22: int = 0
	codesused: list = None
	codes_needing_notifs: list = None
	total_play_time: int = 0
	last_save_date: str = ""
	dlc: list = None
	unknown28: list = None
	region_game_stages: list = None
	world_discovery: list = None
	badass_mode: int = 0
	weapon_mementos: list = None
	item_mementos: list = None
	save_guid: str = ""
	applied_customizations: list = None # Current skins?
	black_market: list = None
	active_mission: int = 0
	challenges: list = None
	level_challenge_unlocks: list = None
	one_off_level_challenges: list = None
	bank: list = None
	challenge_prestiges: int = 0
	lockout_list: list = None
	is_dlc_class: int = 0
	dlc_class_package: int = 0
	fully_explored: list = None
	unknown47: list = None
	golden_keys: int = 0 # Number "notified", whatever that means.
	last_playthrough: int = 0
	show_new_playthrough_notif: int = 0
	rcvd_default_weap: int = 0
	queued_training_msgs: list = None
	packed_item_data: list = None # TODO
	packed_weapon_data: list = None # TODO
	awesome_skill_disabled: int = 0
	max_bank_slots: int = 0 # Might be useful when looking for a place to put stuff
	vehicle_skins: list = None
	vehicle_steering_mode: int = 0
	has_played_uvhm: int = 0
	overpower_levels: int = 0
	last_overpower_choice: int = 0

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
	return "Level %d %s" % (savefile.level, savefile.playerclass)

dir = os.path.expanduser("~/.local/share/aspyr-media/borderlands 2/willowgame/savedata")
dir = os.path.join(dir, os.listdir(dir)[0]) # If this bombs, you might not have any saves
for fn in sorted(os.listdir(dir)):
	if not fn.endswith(".sav"): continue
	if fn != "save000a.sav": continue # Hack: Use the smallest file available
	print(fn)
	try: print(parse_savefile(os.path.join(dir, fn)))
	except SaveFileFormatError as e: print(e.args[0])
