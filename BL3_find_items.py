# Parallel to BL1 and BL2 savefile readers. The name's a bit orphanned now.
# See https://github.com/FromDarkHell/BL3SaveEditor for a lot of great info.
import argparse
import binascii
from BL1_find_items import FunctionArg, Consumable
import Protobufs.OakSave_pb2 as pb2 # protoc -I=../BL3SaveEditor/BL3Tools ../BL3SaveEditor/BL3Tools/Protobufs/*.proto --python_out=.

class SaveFileFormatError(Exception): pass

# Taken straight from the SaveBogoCrypt data block from gibbed, see above URL
_BOGOCRYPT_PFX = (0x71, 0x34, 0x36, 0xB3, 0x56, 0x63, 0x25, 0x5F,
		0xEA, 0xE2, 0x83, 0x73, 0xF4, 0x98, 0xB8, 0x18,
		0x2E, 0xE5, 0x42, 0x2E, 0x50, 0xA2, 0x0F, 0x49,
		0x87, 0x24, 0xE6, 0x65, 0x9A, 0xF0, 0x7C, 0xD7)
_BOGOCRYPT_XOR = (0x7C, 0x07, 0x69, 0x83, 0x31, 0x7E, 0x0C, 0x82,
		0x5F, 0x2E, 0x36, 0x7F, 0x76, 0xB4, 0xA2, 0x71,
		0x38, 0x2B, 0x6E, 0x87, 0x39, 0x05, 0x02, 0xC6,
		0xCD, 0xD8, 0xB1, 0xCC, 0xA1, 0x33, 0xF9, 0xB6)

def bogoencrypt(data):
	data = list(data)
	for i, b in enumerate(data):
		data[i] = b ^ (_BOGOCRYPT_PFX[i] if i < 32 else data[i-32]) ^ _BOGOCRYPT_XOR[i % 32]
	return bytes(data)

def bogodecrypt(data):
	data = list(data)
	for i, b in reversed(list(enumerate(data))):
		data[i] = b ^ (_BOGOCRYPT_PFX[i] if i < 32 else data[i-32]) ^ _BOGOCRYPT_XOR[i % 32]
	return bytes(data)

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

class ConsumableLE(Consumable):
	"""Little-endian bitwise consumable"""
	def get(self, num):
		return super().get(num)[::-1]
	def int(self, size):
		return int(self.get(size), 2)
	@classmethod
	def from_bits(cls, data):
		"""Create a bitfield consumable from packed eight-bit data"""
		return cls(''.join(format(x, "08b")[::-1] for x in data))

class Database:
	# Namespace away all of these things that get loaded from JSON
	loaded = False
	maxver = 0

def db_preload():
	if Database.loaded: return
	import pathlib, json
	path = pathlib.Path(__file__).parent.parent / "BL3SaveEditor/BL3Tools/GameData/Items"
	print(path)
	with open(path / "SerialDB/Inventory Serial Number Database.json", encoding="utf-8-sig") as f:
		Database.serial = json.load(f)
	Database.bits_for_category = {}
	for id, info in Database.serial.items():
		# Each info mapping has "versions" and "assets", and nothing else
		for ver in info["versions"]:
			Database.maxver = max(ver["version"], Database.maxver)
		Database.bits_for_category[id] = ver["bits"] # assumes there's at least one version, and that the last is the one we'll use
		# To be properly correct, bits_for_category should be doing a lookup based on the version.
		# I can't be bothered, and am assuming that the files are the latest version.
		info["assets"] # bomb early if it's missing
	Database.loaded = True

def parse_item_serial(data):
	db_preload()
	if data[0] not in (3, 4): raise SaveFileFormatError("Bad serial number on item: %r" % serial)
	seed = int.from_bytes(data[1:5], "big")
	data = data[:5] + bogocrypt(seed, data[5:], "decrypt")
	crc16 = int.from_bytes(data[5:7], "big")
	data = data[:5] + b"\xFF\xFF" + data[7:]
	crc = binascii.crc32(data)
	crc = (crc >> 16) ^ (crc & 65535)
	if crc != crc16: raise SaveFileFormatError("Checksum mismatch")
	data = ConsumableLE.from_bits(data[7:])
	mark = data.get(8); assert mark == "10000000"
	ver = data.int(7); assert ver <= Database.maxver
	def get_category(cat):
		return Database.serial[cat]["assets"][data.int(Database.bits_for_category[cat]) - 1]
	balance = get_category("InventoryBalanceData")
	invdata = get_category("InventoryData")
	manufac = get_category("ManufacturerData")
	level = data.int(7)
	return level

def parse_savefile(fn):
	with open(fn, "rb") as f: data = Consumable(f.read())
	if data.get(4) != b"GVAS": raise SaveFileFormatError("Invalid magic number - corrupt file?")
	header = data.get(18) # Version numbers, various. Probably irrelevant.
	buildid = data.str()
	fmtver = data.int()
	# The keys are GUIDs and the meanings are opaque. I don't know if order is significant but let's preserve it.
	fmt = {data.get(16): data.int() for _ in range(data.int())}
	savetype = data.str()
	remaining = data.int()
	if remaining != len(data): raise SaveFileFormatError("Remaining length incorrect (got %d, expecting %d)" % remaining, len(data))
	raw = bogodecrypt(data.peek())
	char = pb2.Character(); char.ParseFromString(raw)
	# Interesting things:
	# char.resource_pools -- ammo
	# char.experience_points -- total XP? I don't think character level is stored.
	# char.inventory_items -- all inventory and equipment. Might not include banked items, which seem to be on your profile??
	# char.equipped_inventory_list -- indices into char.inventory_items
	# char.mission_playthroughs_data -- all missions, completed and not completed
	# for missions in char.mission_playthroughs_data:
	#  for mission in missions.mission_list:
	#   if mission.status == 1: is an active mission
	# char.sdu_list -- all the SDU upgrades you've purchased
	# Money?? Not sure how that's stored. I actually expected that to be one of the easy verifications.
	for item in char.inventory_items:
		print(parse_item_serial(item.item_serial_number))

def main(args=None):
	parser = argparse.ArgumentParser(description="Borderlands 3 save file reader")
	parser.add_argument("-f", "--file", help="Specify the file to parse")
	# TODO: Know the standard directory and go looking there
	args = parser.parse_args(args)
	print(args)
	if args.file: parse_savefile(args.file)

if __name__ == "__main__": main()
