# Parallel to BL1 and BL2 savefile readers. The name's a bit orphanned now.
# See https://github.com/FromDarkHell/BL3SaveEditor for a lot of great info.
import argparse
import base64
import binascii
import json
import pathlib
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
	def inv_key_for_balance(bal):
		# If the balance has a deduplication marker, strip that.
		bal = bal.split("#")[0]
		# The lookup may need to be done on the lowercased version.
		return Database.balance_to_inv_key.get(bal) or Database.balance_to_inv_key.get(bal.lower())

def db_preload():
	if Database.loaded: return
	path = pathlib.Path(__file__).parent.parent / "BL3SaveEditor/BL3Tools/GameData/Items/Mappings"
	with open(path / "../SerialDB/Inventory Serial Number Database.json", encoding="utf-8-sig") as f:
		Database.serial = json.load(f)
	Database.bits_for_category = {}
	for id, info in Database.serial.items():
		# Each info mapping has "versions" and "assets", and nothing else
		for ver in info["versions"]:
			Database.maxver = max(ver["version"], Database.maxver)
		Database.bits_for_category[id] = ver["bits"] # assumes there's at least one version, and that the last is the one we'll use
		# To be properly correct, bits_for_category should be doing a lookup based on the version.
		# I can't be bothered, and am assuming that the files are the latest version.

		# Sometimes there are duplicate entries in the asset list.
		# I don't know what the deal is, but I mainly just want things to round-trip
		# correctly, so let's deduplicate. Nothing ever has a hash, so we use that.
		dedup = {}
		for i, pth in enumerate(info["assets"]):
			if pth in dedup:
				dedup[pth] += 1
				info["assets"][i] = pth + "#" + str(dedup[pth])
			else: dedup[pth] = 1
		
	for fn in "balance_to_inv_key", "part_name_mapping", "prefix_name_mapping":
		with open(path / (fn + ".json"), encoding="utf-8-sig") as f:
			setattr(Database, fn, json.load(f))
	Database.loaded = True

class Item:
	@classmethod
	def from_serial(cls, data):
		db_preload()
		self = cls()
		self.version = data[0]
		if self.version not in (3, 4): raise SaveFileFormatError("Bad serial number on item: %r" % data)
		self.seed = int.from_bytes(data[1:5], "big")
		data = data[:5] + bogocrypt(self.seed, data[5:], "decrypt")
		crc16 = int.from_bytes(data[5:7], "big")
		data = data[:5] + b"\xFF\xFF" + data[7:]
		crc = binascii.crc32(data)
		crc = (crc >> 16) ^ (crc & 65535)
		if crc != crc16: raise SaveFileFormatError("Checksum mismatch")
		data = ConsumableLE.from_bits(data[7:])
		self.mark = data.int(8); assert self.mark == 128
		self.dbver = data.int(7); assert self.dbver <= Database.maxver
		def get_category(cat):
			return Database.serial[cat]["assets"][data.int(Database.bits_for_category[cat]) - 1]
		self.balance = get_category("InventoryBalanceData")
		self.invdata = get_category("InventoryData")
		self.manufac = get_category("ManufacturerData")
		self.level = data.int(7)
		invkey = Database.inv_key_for_balance(self.balance)
		if invkey:
			self.parts = [get_category(invkey) for _ in range(data.int(6))]
			self.generic_parts = [get_category("InventoryGenericPartData") for _ in range(data.int(4))]
			self.additional = [data.int(8) for _ in range(data.int(8))]
			zero = data.int(4); assert zero == 0
			if self.version == 4: self.reroll_count = data.int(8)
		# We're done parsing. The remaining bits should all be zero, and just enough to fill out a byte.
		if len(data) >= 8: raise SaveFileFormatError("Too much data left over!! %r" % data.peek())
		if data.peek() != "0" * len(data): raise SaveFileFormatError("Non-zero data left! %r" % data.peek())
		return self

	def serial(self):
		# Inverse of from_serial()
		db_preload()
		# We need to store everything big-endian. Collect up a series of bits.
		def binbe(n, w): return format(n, "0%db" % w)[::-1]
		def put_category(cat, val):
			return binbe(Database.serial[cat]["assets"].index(val) + 1, Database.bits_for_category[cat])
		bits = [
			binbe(self.mark, 8),
			binbe(self.dbver, 7),
			put_category("InventoryBalanceData", self.balance),
			put_category("InventoryData", self.invdata),
			put_category("ManufacturerData", self.manufac),
			binbe(self.level, 7)
		]
		invkey = Database.inv_key_for_balance(self.balance)
		if invkey:
			bits.append(binbe(len(self.parts), 6))
			for part in self.parts: bits.append(put_category(invkey, part))
			bits.append(binbe(len(self.generic_parts), 4))
			for part in self.generic_parts: bits.append(put_category("InventoryGenericPartData", part))
			bits.append(binbe(len(self.additional), 8))
			for n in self.additional: bits.append(binbe(n, 8))
			bits.append("0000")
			if self.version == 4: bits.append(binbe(self.reroll_count, 8))
		bits = "".join(bits)
		residue = 8 - len(bits) % 8
		if residue != 8: bits += "0" * residue
		data = int(bits[::-1], 2).to_bytes(len(bits)//8, "little")
		data = bytes([self.version]) + self.seed.to_bytes(4, "big") + b"\xFF\xFF" + data
		crc = binascii.crc32(data)
		crc = (crc >> 16) ^ (crc & 65535)
		return data[:5] + bogocrypt(self.seed, crc.to_bytes(2, "big") + data[7:], "encrypt")

	def __str__(self):
		name = self.balance.split(".")[-1] # Fallback: Use the balance ID.
		title = Database.part_name_mapping.get(self.balance, "")
		pfx = Database.prefix_name_mapping.get(self.balance, "")
		for part in self.parts:
			title = Database.part_name_mapping.get(part, title)
			pfx = Database.prefix_name_mapping.get(part, pfx)
		if pfx and title: name = pfx + " " + title
		elif title: name = title
		return "<Item: %s lvl %d>" % (name, self.level)

def encode_int(n):
	return n.to_bytes(4, "little")
def encode_str(s):
	return encode_int(len(s) + 1) + s.encode("ascii") + b"\0"

def parse_savefile(fn, args):
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
		obj = Item.from_serial(item.item_serial_number)
		if obj.serial() == item.item_serial_number:
			print(obj, "-- ok")
		else:
			print(base64.b64encode(item.item_serial_number).decode())
			print(base64.b64encode(obj.serial()).decode())
	raw = char.SerializeToString() # This does not fully round-trip. Hmm.
	data = [
		b"GVAS",
		header,
		encode_str(buildid),
		encode_int(fmtver),
		encode_int(len(fmt)),
	]
	for k, v in fmt.items(): # Perfect bit-for-bit round-tripping depends on iteration order. I don't think it really matters though.
		data.append(k)
		data.append(encode_int(v))
	data.append(encode_str(savetype))
	data.append(encode_int(len(raw)))
	data.append(bogoencrypt(raw))
	data = b"".join(data)
	with open(fn, "rb") as f: origdata = f.read()
	if data == origdata: print("SUCCESS")
	if args.save:
		with open(fn, "wb") as f: f.write(data)
		print("Saved.")

def main(args=None):
	parser = argparse.ArgumentParser(description="Borderlands 3 save file reader")
	parser.add_argument("-f", "--file", help="Specify an exact file name")
	parser.add_argument("--save", action="store_true", help="Write the file back")
	parser.add_argument("--steam-dir", help="Path to Steam library", default="~/.steam/steam")
	parser.add_argument("--steam-user", help="Steam user ID, or all or auto", default="auto")
	parser.add_argument("--files", help="File name pattern", default="*.sav")
	# TODO: Know the standard directory and go looking there
	args = parser.parse_args(args)
	print(args)
	if args.file: parse_savefile(args.file, args)
	else:
		path = pathlib.Path(args.steam_dir).expanduser()
		# TODO: If we're on an actual Windows or Wine installation, locate the saves dir
		# suitable for that, as opposed to this, which is for Proton
		docu = path / "steamapps/compatdata/397540/pfx/drive_c/users/steamuser/Documents"
		savedir = docu / "My Games/Borderlands 3/Saved/SaveGames" # This part shouldn't change.
		if args.steam_user in ("auto", "all"):
			# Steam IDs are all digits. Anything else, ignore.
			names = [fn for fn in savedir.iterdir() if fn.name.isnumeric()]
			if args.steam_user == "auto" and len(names) > 1:
				print("Multiple Steam users have data here. Please select:")
				for fn in names:
					print("--steam-user", fn.name)
				return 0
		else:
			names = [savedir / args.steam_user]
			if not names[0].is_dir():
				print("Steam user not found")
				return 1
		for fn in names:
			for save in fn.iterdir():
				if not save.match(args.files): continue
				# Special case: the profile is not a save file.
				if save.name == "profile.sav": continue
				parse_savefile(save, args)

if __name__ == "__main__": main()
