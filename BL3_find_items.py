# Parallel to BL1 and BL2 savefile readers. The name's a bit orphanned now.
# See https://github.com/FromDarkHell/BL3SaveEditor for a lot of great info.
import argparse
import base64
import binascii
import json
import pathlib
import random
from BL1_find_items import FunctionArg, Consumable
import Protobufs.OakSave_pb2 # protoc -I=../BL3SaveEditor/BL3Tools ../BL3SaveEditor/BL3Tools/Protobufs/*.proto --python_out=.
import Protobufs.OakProfile_pb2

class SaveFileFormatError(Exception): pass

# Taken straight from the SaveBogoCrypt data block from gibbed, see above URL
_BOGOCRYPT_PFX = {
	"OakSaveGame": (
		0x71, 0x34, 0x36, 0xB3, 0x56, 0x63, 0x25, 0x5F,
		0xEA, 0xE2, 0x83, 0x73, 0xF4, 0x98, 0xB8, 0x18,
		0x2E, 0xE5, 0x42, 0x2E, 0x50, 0xA2, 0x0F, 0x49,
		0x87, 0x24, 0xE6, 0x65, 0x9A, 0xF0, 0x7C, 0xD7,
	),
	"BP_DefaultOakProfile_C": (
		0xD8, 0x04, 0xB9, 0x08, 0x5C, 0x4E, 0x2B, 0xC0,
		0x61, 0x9F, 0x7C, 0x8D, 0x5D, 0x34, 0x00, 0x56,
		0xE7, 0x7B, 0x4E, 0xC0, 0xA4, 0xD6, 0xA7, 0x01,
		0x14, 0x15, 0xA9, 0x93, 0x1F, 0x27, 0x2C, 0x8F,
	),
}
_BOGOCRYPT_XOR = {
	"OakSaveGame": (
		0x7C, 0x07, 0x69, 0x83, 0x31, 0x7E, 0x0C, 0x82,
		0x5F, 0x2E, 0x36, 0x7F, 0x76, 0xB4, 0xA2, 0x71,
		0x38, 0x2B, 0x6E, 0x87, 0x39, 0x05, 0x02, 0xC6,
		0xCD, 0xD8, 0xB1, 0xCC, 0xA1, 0x33, 0xF9, 0xB6,
	),
	"BP_DefaultOakProfile_C": (
		0xE8, 0xDC, 0x3A, 0x66, 0xF7, 0xEF, 0x85, 0xE0,
		0xBD, 0x4A, 0xA9, 0x73, 0x57, 0x99, 0x30, 0x8C,
		0x94, 0x63, 0x59, 0xA8, 0xC9, 0xAE, 0xD9, 0x58,
		0x7D, 0x51, 0xB0, 0x1E, 0xBE, 0xD0, 0x77, 0x43,
	),
}

DISPLAY_ORDER = {k:i for i,k in enumerate([
	"Weapon1", "Weapon2", "Weapon3", "Weapon4",
	"Shield", "GrenadeMod", "ClassMod", "Artifact",
])}

def bogoencrypt(data, savetype):
	data = list(data)
	PFX, XOR = _BOGOCRYPT_PFX[savetype], _BOGOCRYPT_XOR[savetype]
	for i, b in enumerate(data):
		data[i] = b ^ (PFX[i] if i < 32 else data[i-32]) ^ XOR[i % 32]
	return bytes(data)

def bogodecrypt(data, savetype):
	data = list(data)
	PFX, XOR = _BOGOCRYPT_PFX[savetype], _BOGOCRYPT_XOR[savetype]
	for i, b in reversed(list(enumerate(data))):
		data[i] = b ^ (PFX[i] if i < 32 else data[i-32]) ^ XOR[i % 32]
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

def armor_serial(serial): return base64.b64encode(serial).decode("ascii").strip("=")
def unarmor_serial(id): return base64.b64decode(id.strip("{}").encode("ascii") + b"====")

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

	def get_title(self):
		title = Database.part_name_mapping.get(self.balance.split("#")[0], "")
		pfx = Database.prefix_name_mapping.get(self.balance.split("#")[0], "")
		for part in self.parts:
			title = Database.part_name_mapping.get(part.split("#")[0], title)
			pfx = Database.prefix_name_mapping.get(part.split("#")[0], pfx)
		if pfx and title: return pfx + " " + title
		return title or self.balance.split(".")[-1] # Fallback: Use the balance ID.

	def __str__(self):
		return "<Item: %s lvl %d>" % (self.get_title(), self.level)

def encode_int(n):
	return n.to_bytes(4, "little")
def encode_str(s):
	return encode_int(len(s) + 1) + s.encode("ascii") + b"\0"

library = {
	# Weapons: Sniper
	"BAAAADJWH6YmuyneP5fKD4GcmcHE5Y+pnDp7EJYBO3x7MmNgPagIew": "Woodblocker",
	"BAAAADLV+tD7nin/P5fKD+cQgMI3U5uCRwcI26Q4KEeWJiTJjds": "Cold Shoulder",
	"BAAAADJOXHfN639/L5fKD4Ec4E7F5Y76nDp5EJYBM3z6sglwzfh8Tg": "Null Pointer",
	"BAAAADJWkwCN7wXBf5/KD4EcgELI5xtoeoQ00jSjmPVuu+XTSqx4lcY": "Brashi's Dedication",
	"BAAAADIN8lHXGGv/P5fKD4EuoMLEZBw8ohvzu/ZZvmP2NEVqtJb/": "Abundant ASMD", # Underwhelming due to slow projectile speed
	"BAAAADISnUZdHijeP5fKD4FcmcHE5W7mnDriCdYBO3x7sgnxjZDIxA": "Skullmasher", # from diamond key
	"BAAAADLU/8TsGGv/P5fKD4EuhsLE1XQ8Il0J+PZZomn8luW4ibDs": "Lyuda",
	"BAAAADIZ/8TsGGv/P5fKDwEuhsLEvWw8Il0J+PZZonazluWwsbBu": "Lyuda", # Dropped at lvl 72!!
	"BAAAADLUlJb/Gin/P6/JDYErEUJ6PPH9P18QR1Rj22d1+pI": "THE TWO TIME", # Hitscan weapon - no scope though
	"BAAAADJSPZZUwineP5fKD4EcmdLE5biCnDrcCtYBO3z6sqkmrZhsRA": "Monocle",
	"BAAAADJSPZZMwineP5fKD4EcmtLE5dt0nDrcCtYBO3x7sqkmrZhsRA": "Monocle",
	"BAAAADIXEZX3Gyn/P5fKwwEcgJpoZSXr7gUpkc0scOVTlUV0zQ": "The Hunt(er)",
	"BAAAADIXEZX3Gyn/P5fKxQEcgC2wZaXr7gUpkc2sv6LT1UV0TA": "The Hunt(ed)",
	"BAAAADKOM5X3Gyn/P5fKxwEcgL0jZSUY5EUrkdGmOgeDNeF+8Q": "Storm",
	"BAAAADIQkbScdCH+P5fKD4GIwcLEtjQ8onH6+/RJovbzluyIoc5v": "Muckamuck",
	# Weapons: Shotgun
	"BAAAADLSpIL9Gin/P5dWDoAcvLRE20zfXSdp4Njld+bM3W10": "Redundant Face-puncher",
	"BAAAADKBvJL/Gin//5vID2y1APybnRqfTwyP4nTz4S9ahg": "T.K's Wave",
	"BAAAADKBvJL/Gin/j5vID1SwAPybnRqfTwyMYvXA2S9Ehg": "T.K's Wave",
	"BAAAADLTuoL9Gin/P5dGPoEcm5xEW9rcXSdp4MflNVa02RPz": "The Butcher",
	"BAAAADKOuYL9Gin/P5dqDoAcsvhEW808XSVp/lIjOcA8hGfX": "Projectile Recursion",
	"BAAAADKPuYL9Gin/P5dqDoAcbLhEW808XSVp/tRgOdA8hGNX": "Projectile Recursion",
	"BAAAADLRtJL/Gil/s5bKcdGcviC85Dj3FLkXOBQg4h70": "Hellwalker",
	"BAAAADKNpIL9Gin/P5dePoEcORZE2+bFHSdp8hXjEeIczXXC": "Iron-Willed Fingerbiter",
	"BAAAADLBtJL/mhrfP5dBGgGiOKoFxSCmtMgv34Uj+mY": "Flakker",
	"BAAAADLRtJL/Gil/s5bKmgKcPuClpDj3BoqXXyQzGR70": "Conference Call",
	"BAAAADKLuYL9Gin/P5dqDoAcQHBE23E2nSVp4EcldRaE6WV1": "Supercharged Polybius",
	"BAAAADLT+rYjCiv/P5fKDxEtgMIKkJsC3WRL2bQ4qKEZ9e0k01A": "The Butcher",
	# Weapons: SMG
	"BAAAADKMVpX3Gyn/P5fKwQEcgO4tZSXnzkUrkd8FLK+TXHV0/A": "Cloud Kill",
	"BAAAADKP9ZT3Gyn/P5fK3wEcgPiLZSV8zEUrkd+KK29St0wy/Q": "Eviscerating Cutsman",
	"BAAAADLYlJb/Gin/P7/JDYGz0UL6Jcv9PV8C3E8qLO8xjSg": "Eviscerating Cutsman", # from diamond key
	"BAAAADLflJb/Gin/P7epD4Gfw0L6KYH9P18QdBBMOJ/8gQ4": "Bankrolled Predatory Lending", # Ammo is money, so you have a VAST reserve
	"BAAAADLesYL9Gin/P5duDoAcXS1EW/ssnSRp5urmHBKO0Rd6": "Sleeping Giant", # Excellent ROF, can give magazine-long bonuses
	"BAAAADKBvJL/Gin/T5HOD5EOAHx9PZqdTx4aPbtiqPdEng": "Ten Gallon",
	"BAAAADKLuYL9Gin/P5daPoEclSdE24tmnSVp4MflOxBENWdJ": "The Boo",
	"BAAAADLScZX3Gyn/P5fKw5kcgGkTZSVjhkUpkc0s8OlEBY1u9A": "Redistributor",
	"BAAAADLdlJb/Gin/P7epD4HyG0J6KoL9P18QzdTgyozwgws": "XZ41",
	"BAAAADLdlJb/Gin/P6epD4HUYEJ6KoL9P18QzdQgy4z0gws": "XZ41",
	"BAAAADJM/ZX3Gyn/P5fKx5kcgPm2ZSUl1l8pkc0tv0JTDbFsTA": "Handsome Jackhammer",
	"BAAAADJN83etTCneP5fKD4FcmdLE5c+qnDpSaVYCO3rkfc7IrbwE+Q": "Arctic Night Hawkin",
	"BAAAADLRciGNMwR/L5fKD4EcoM/M5T0TnDpSaVYCM3rlssnIrbgC8A": "Arctic Night Hawkin",
	"BAAAADLdlJb/Gin/P7fJD4HTqkJ6BcE9PV8Q9B8hH3bhh74": "Firesale Long Musket",
	"BAAAADLFl5r3Gyn/P5fK3QEcgNATZSXVzkUrkd8FrJanBH1y9w": "Devoted",
	"BAAAADKTMJT3Gyn/P5fKxZkcgCdhZSWshUUpkc2yf+pUDbFs9w": "Defrauding Crossroad",
	"BAAAADJVspv3Gyn/P5fK3wEcgM9ZZaWJz0Urkd+Eq4w8n3R0fA": "The Emperor's Condiment",
	"BAAAADJVspv3Gyn/P5fKwQEcgKVyZaWJz0Urkd+KK488n3R0fA": "The Emperor's Condiment",
	"BAAAADLBtJL/2jDvP5dA+AGieptFxFgmuzkwsawjmWY": "Bangarang",
	"BAAAADJDpYL9Gin/P5daDoAc8HBEW+9uXSVp8nBAsOLl8X/L": "E-Gone",
	"BAAAADKO/NFlGuryHpfKD4EcQNvU5RtXfoS0okxjm+Vuu+Wz2tRA98M": "Hostile L0V3M4CH1N3",
	# Weapons: AR
	"BAAAADIWpoL9Gin/P5daPoEcRpREW+StHSVp8vB28o81qTfB": "Ogre",
	"BAAAADIZpoL9Gin/P5dSPoEcYKlEW+StHSVp8v728Y8VrTdB": "Ogre",
	"BAAAADKBvJL/Gin/f5HOD+l5APwr7RqfTx6jbdZQGeJChQ": "Lead Sprinkler",
	"BAAAADKBvJL/Gin/X5HODyKtAPwr7RqfTx6ibTZTMRpMhQ": "Lead Sprinkler",
	"BAAAADKBvJL/Gin/v5HODwOAAPw77BqfTx4iYLXTeDZIgA": "Cuttin' Hand Of Glory",
	"BAAAADLnlJb/Gin/P7+pD4GlW0J6Cgu9PV8CXcPIMEtskJ0": "Sickle",
	"BAAAADIXUJT3Gyn/P5fK3QEcgEcgZSVjHIUqkc0yf6WyPV0USw": "Venomous Barrage",
	"BAAAADKddnJnso1/L5fKD4EcgM/M5SM2nDqf6NYDM27cYQSqHHQ4Yw": "Lucian's Call",
	"BAAAADLK0ZT3Gyn/P5fKx5kcgKntZSWY5QQokbWscGVW3h0YcA": "Hawt Sawbar",
	"BAAAADJRPKD8nin/P5fKD+QQgMIgr5uCOP0K2KRANq43c0XA1+M": "Hawt Sawbar",
	"BAAAADLKnNZmG2v/P5fKDwEuhsLEl448IiDz+vVZ2ui8tg8z2bjV": "Hawt Sawbar",
	"BAAAADLBtJL/GunnPJfKIaecvgfU5Dr/FMVrGAe6sGdV": "The Dictator",
	"BAAAADKBvJL/Gin/f1HKD8q4APx6HRueTxg7MlR3Wjpcmw": "Hawt Pain is Power", # Can set YOU on fire
	"BAAAADJKuIL9Gin/P5daPoEcMvtEWzuF3yRp4Nhl1Md03GN1": "Try-Bolt",
	"BAAAADKP9Jr/Gin/P9cMD4FyykJ6E+s8Pm8Q/a1u2WbDnt8": "Carrier",
	"BAAAADKZX5X3Gyn/P5fKx5kcgMSWZSUEDAUrkd+Lq8wz9DUs/A": "Storming Shredifier",
	"BAAAADLJ2Gf8nin/P5fKD+QQgMKmE5uCpBQL26QqkbLd4oRh40o": "Engulfing Shredifier",
	"BAAAADLBtJL/GinmPJfKjtScvgfU5Dr/FMXrGAe6sGdV": "The Dictator", # Horizontal bullet spread
	"BAAAADJYeHJ32nWwf5/KD4EcgKLC4RtXYYQ0dcUjmfV8Ejma9ObFee4": "Engulfing Faisor",
	"BAAAADIYdYN+o7d/L5fKD4EcgM/M5eW/nDqF6NYDM27Toed553no0w": "Nuclear Faisor",
	"BAAAADLelJb/Gin/P4/JDYFUiEJ6wRo9PF8Q6ohG61TZ6bU": "Tamed Star Helix",
	"BAAAADJRHQdmMijeP5fKD4FcmcHE5cK1nDpp+VYCO3x6fQ75jdhsxQ": "Venomous Kaos",
	"BAAAADIIEZX3Gyn/P5fKxZkcgGykZaXfJ8cqkc0yf+VTvVgASQ": "Burning Alchemist",
	"BAAAADKBvJL/Gin/X1HKD6VqAHwb5ZqcTx6yexNhcssUjw": "Warlord",
	"BAAAADLYlJb/Gin/P7fJDYEMbkL6FBO9P18QXQ/Dycf0/zE": "Loaded Gatling Gun",
	"BAAAADKBvJL/Gin/b1HKD30SAPx6HRueTxg7MnR3YgJcmw": "Hawt Embrace the Pain",
	"BAAAADLAlZL/Gin/v47JD4HbmUL6xek8PmcQEqby+ateH2Y": "Rebel Yell",
	# Weapons: Pistol
	"BAAAADLNk5T3Gyn/P5fKxwEcgJtaZSWeTQUpkbOtsGJSrWF8cg": "Maggie",
	"BAAAADLNk5T3Gyn/P5fKxQEcgFp0ZSWeTQUpkcmQsGJCpWF8cg": "Maggie",
	"BAAAADLIu4L9Gin/P5dSDoAcKR5EW3A2XiVp4Fj/edaFPXX3": "Starkiller",
	"BAAAADLIu4L9Gin/P5duDoAc1PpEW3A2XiVp4Fj/edaFPXX3": "Starkiller",
	"BAAAADJFtJL/Gin/9LfKD6MpAPySppqcR4Kxg++Gs694sg": "Omniloader",
	"BAAAADLblJb/Gin/P7+pD4EoKUL6E5P+PV8Qdc5haZf4+z4": "Superball",
	"BAAAADJFtJL/Gin/XJvKD3hPAHww3ZqeR54NiJXGKFw4sQ": "Peacemonger",
	"BAAAADJS88ZXGijeP5fKD4GcmcHE5eUVnDo/ERUCO0TMYKmiruhMwg": "Oozing Roisen's Thorns",
	"BAAAADKS88ZXGijeP5fKD4FcmcHE5YWWnDo/ERUCOxZlP0mlrvxGwg": "Oozing Roisen's Thorns",
	"BAAAADLgpYL9Gin/P5fSjIEcTy5EW02nHSVp4EUm+2d92GP7": "The Leech",
	"BAAAADIPv4L9Gin/P5fqjIEcbilE2xBlHiZpmEUoNLeEvWNx": "The Killing Word",
	"BAAAADKBvJL/Gin/v5HOD7uuAHxTtxqfTxo4JbbwQQJMig": "Dead Chamber",
	"BAAAADJKMgb8nin/P5fKD0s8gMKNDZuC6t4I2KRAKi/xN3Zg0Xc": "Extreme Hangin' Chadd", # Always incendiary. Never needs ammo.
	"BAAAADJKMgb8nin/P5fKD0s8gMJUrJuC6t4I2KRAKmwRN3Zg0Xc": "Extreme Hangin' Chadd",
	"BAAAADJKMgb8nin/P5fKD0o8gMJfHZuC6t4I2KQGiSwRN0580Xc": "Extreme Hangin' Chadd",
	"BAAAADLNpIL9Gin/P5dSPoEcVulE212lHSVp4EO9uHSoLXt9": "Storming Infinity", # Never needs ammo
	"BAAAADKBvJL/Gin/T5HOD7uQAHwatRqfT2CF8nOXIB40mg": "The Companion", # You can't take the sky from me...
	"BAAAADLclJb/Gin/P6fJDYFfl0L6jkm9P19u9V8Gn044mQ0": "The Duc",
	"BAAAADKNHZT3Gyn/P5fKxZkcgNcjZSW/xgYokbWwcuJizFVSeg": "Melty Cheep Pestilence",
	"BAAAADLAlZL/Gin/v47JD4H5mEL66Fo9PGeMrV0aS42yJ68": "Venomous Hornet",
	"BAAAADLLspX3Gyn/P5fKyQEcgOW/ZaWqlkYrkc2sY+TFR6UIyw": "Expert Hellshock", # Dropped at lvl 72!!
	"BAAAADKR9ZX3Gyn/P5fKxZkcgG/PZaWR9sYqkfWarUMD9SVocw": "Girth Blaster Elite", # From the toy box
	"BAAAADKBvJL/Gin/X1HKD0DnAHylb1mdTx6E5jXiSeo6jw": "Hyper-Hydrator", # From the toy box
	"BAAAADKBvJL/Gin/f1HKD3/KAHx6/RqdTx6EZplx4t8Ujg": "Magnificent",
	"BAAAADJOPOJGG2v/P5fKDwEuhsLEGXk8IgrjOPdZyPdh8H8jNcxu": "Burning Breeder",
	"BAAAADINEpX3Gyn/P5fKw5kcgNkcZSUrTgUpkckQ8OJDpXlqTQ": "Amazing Grace", # Go for crits
	"BAAAADKR8lb9nin/P5fKD+QQgMJ3eJsCydwI2KRAKm8RwG0o5eI": "Kemik Linoge",
	"BAAAADLRtJL/Gik/s5bK09+cPoeV5Dj3ArYCnoHTxA70": "The Flood", # Basically a SMG
	"BAAAADKh9Jr/Gin/P8cMD4GGG0L66Fo9PG+MrV2EdSJOBIk": "Venomous Hornet",
	"BAAAADLRXbD8nin/P5fKD+UQgMLFw5uCwuzI2qQAAK/+p3581eo": "Burning Occultist",
	"BAAAADLBtJL/Gqn5O5eHIwEiVIJFxVA6qS1Sa2t4+G4": "Shocking AAA",
	"BAAAADLDtJL/GilnPpbKxQycPjidZDrvBuNjdTnwGnFk": "Poison Bangarang",
	"BAAAADLLspX3Gyn/P5fKwQEcgAG9ZaWqlkYrkc2towWlRKUIyw": "Hellshock",
	"BAAAADJPHOL8nin/P5fKD+UQgMJqjpuCEu3I2qRSKfMQ516I1VI": "Breeder",
	"BAAAADKBvJL/Gin/f1HKDyGNAPwUbFmdTx4Eof0W0v9cgA": "Thunderball Fists",
	"BAAAADLDuIL9Gin/P5dSPoEcuVtE28NU3iRp2G/3PJSmIRHy": "Devastator ",
	"BAAAADLPv4L9Gin/P5daDoAc6rdEW7jsHSdpnthrnNMU+RNJ": "Wagon Wheel",
	"BAAAADKBvJL/Gin/D1HKD4/9AHx6/RqdTx6eZllB2ttejg": "Pestilent Magnificent",
	# Weapons: Heavy
	"BAAAADLXlJb/Gin/P7+pD4FdYUJ6PjN9PF8Q9UGCGp/887A": "Scourge",
	"BAAAADLBtJL/GmmbL5fKDJqcvjbsJDv/BrSAHBSjfGZV": "Oozing Gettleburger",
	"BAAAADILuIL9Gin/P5daPoEcBMREWxSNHSVp4MdltDVmwEnJ": "Nuclear Jericho",
	"BAAAADISUaEmG2v/P5fKD4F6kMLEO148olEp+/VZ0tLytl8L3cLr": "Hawt Hot Drop",
	"BAAAADLBtJIrjqlBb9/LJ4oewsLE5Ru8HAQ": "Eridian Fabricator", # The Gun Gun, consumes eridium to create weapons
	"BAAAADLYlJb/Gin/P7epD4FDYkL66jJ9PF8QyBWCGm/t+7E": "Tunguska",
	# Grenade mods
	"BAAAADLBQtp/JDJuf7T5AQWmhMZ45Ru8": "Nagata",
	"BAAAADLBtFnCmpesrJfrNJEozjzA4Rm9HA": "Whispering Ice",
	"BAAAADLBtGctmpcCrhfoNIkqBBjAo8e8HA": "Cloning Hex",
	"BAAAADLBtEV3mpcCrhfoNIksBBjA/ce8HA": "MIRV Hex",
	"BAAAADLBtIfFmhflrlfqNIcuBHbA4a28HA": "Surge",
	"BAAAADLBtEmlmpclrZfrNJEGBDDA4e28HA": "Diamond Butt Bomb",
	"BAAAADLBtHocmpckrVfqNIcGBDjA4ee8HA": "Ultraball",
	"BAAAADL2DxLBBri/HLzEPwXeRMLE5Rs": "Storm Front",
	"BAAAADLBtMx4mpfirhfrNIsuzhLA4de8HA": "Fungus Among Us",
	"BAAAADLBtGawmhckrRfrNIsGBDbI6eO8HA": "Cheddar Shredder",
	"BAAAADLBtHMDmhfgrpfrNJEGBBTA4cO8HA": "Red Queen", # from diamond key. Underwhelming, sadly.
	"BAAAADLBtLfwmhcVrxfrNIsGBGzA4au8HA": "Widowmaker", # Tediore variant
	"BAAAADLBlDN/JH9tP7b5H7FOXsYk5Ru8": "NOG Potion #9", # Convert NOGs to fight for you
	"BAAAADKLbRLBjpNOHrzAFbn4asLE5Rs": "ECHO-2",
	"BAAAADLBtBFLmhfQrFfqNIcq0szB4Qu9HA": "Porcelain Pipe Bomb",
	"BAAAADLBtHLWmhcnrRfoNIkyziz64eu8HA": "Generator",
	"BAAAADLBtL0tmpcXrxfrNIsGBGLA4bm8HA": "Fastball",
	"BAAAADLBtG9xmpfjrhfrNIsuBATAo9O8HA": "Cloning Hunter-Seeker",
	"BAAAADLBcat/pDJuv7b5BbGYPsYE5Ru8": "Quasar",
	"BAAAADLBAoh/pDJuf7T5AbGYPtYE5Ru8": "Sticky Quasar",
	"BAAAADLBtIpsmhesrBfrNIsG0tbB4Re9HA": "Chocolate Thunder",
	# Shields
	"BAAAADLBtLfpmhfO59fpNJNyuo/91mu8HA": "Absorbing", # Health Extremophile Shield?
	"BAAAADLBtOL4mhcnrRfrNIsoziz62+u8HA": "Generator", # Power Siphon??
	"BAAAADKtNCzQwancHI+whw4dgMLEcw": "Golden Touch",
	"BAAAADIHahLBKvI/HLzsWwNdBcPE5Rs": "Overflowing Moxxi's Embrace",
	"BAAAADLBmTt/pH8lv7T5F/tsg4S45Ru8": "Mr Caffeine",
	"BAAAADLBtNyRmhfM5FfpNKdCBpWTspa9HA": "Back Ham",
	"BAAAADLBtJL2D6nBUU2KLMIO7rCJqFbxaAU": "Mendel's Multivitamin Shield",
	"BAAAADIlyBJBrfG/HLzYiz1QqsPE5Rs": "The Transformer", # from diamond key
	"BAAAADLBJKJ/pBknf7T5Het+5fGo5Ru8": "Inertia", # One of these
	"BAAAADLBtAYImpfgr9fpNI8GzubG4Xm8HA": "Large", # is a tortoise shield
	"BAAAADLBtHPAmpcc5xfpNJmaZJybogG9HA": "Spike", # Impaler shield??
	"BAAAADLBtHwJmpf05hfpNJmasJWRrim9HA": "Quick Charge", # Faraday Big Boom Blaster?
	"BAAAADLBtIcjmhcl5VfpNKee/o2Lrpu9HA": "Deluxe Badass Combustor",
	"BAAAADLQcxJBFPA/HLzsjbVVtsPE5Rs": "Frozen Heart",
	"BAAAADLBtGjempfM5NfpNJOYCpmfqou9HA": "Brawler Ward",
	"BAAAADLBtH4gmpf05hfpNJmasP2XrCm9HA": "Shield Shredder Big Boom Blaster",
	"BAAAADLBtDnwmhcK59fpNJOYkpOFogO9HA": "Kneel and Heal Front Loader", # Legendary turtle shield, of a sort
	"BAAAADLBtJUmmpcK5xfpNJmalP2fqgW9HA": "Deliverance Red Suit", # Legendary Amp+Roid with constant nova; low shield capac
	"BAAAADLBTQp/JGgkf7T5HeuOg46o5Ru8": "Loop of 4N631",
	"BAAAADKOeBLB/fF/HLzSiXNQlsPE5Rs": "Black Hole",
	# Class mods: Operative
	"BAAAADJ8sGmvKin/Pwwwjz/Ks4HivvHmcqQl77NXFw": "Executor", # Has a different Balance from the below ones
	"BAAAADIAQmiPNSn/PxT/jz+ssIHivvHmciTD1rx0iA": "Executor",
	"BAAAADLOsWmPNSn/P0LIjz+ssIHivvHmciTBnmPXew": "Executor",
	"BAAAADLOsWkPWSn/P+3hjz+ssIHivvHmciTBlrPXew": "Executor", # Hybridized from the above two
	"BAAAADLOi24PWSn/P8C9jz+ssIHivvHmciQKwWRXFw": "Executor",
	"BAAAADJ8im6vKin/P0C3jz+ssIHivvHmcqTBOktRFw": "Executor",
	"BAAAADLOi04UWSn/P/Lqjz+ssIHivvHmcqTyFnx0CA": "Executor",
	"BAAAADLOi26vKin/P5/0jz+ssIHivvHmciQD+UvUew": "Executor",
	"BAAAADJ92CB2NSn/Pxk9jz+ssIHivvHOcqTBLjS2Fw": "Cold Warrior",
	"BAAAADJ/RiB2NSn/P43fjz+ssIHivvHOcqSNH2QRlw": "Cold Warrior",
	"BAAAADLPiZ5zWSn/P3YXjz+ssIHivvHucqT+8lPx+w": "Infiltrator",
	"BAAAADLPt3HPKin/P/itjz+ssIHivvHuciQM/TMXiA": "Infiltrator",
	"BAAAADLPt2HPKin/P8m+jz+ssIHivvHucqTA+EO3+w": "Infiltrator",
	"BAAAADJ6gEavWSn/P0Aljz+ssIHivvHWcqQOn9PXFg": "Shockerator",
	"BAAAADJ6gC4UNCn/PybJjz+ssIHivvHWcqQl23zWFg": "Shockerator",
	"BAAAADLQ8XaUXin/P5V1jz+ssIHivvHeciTaMkSxFw": "Techspert",
	# Class mods: Gunner
	"BAAAADJ0YsjUNyn/P7SOjz8E4ILivstesQ7zJmwUFQ": "Bloodletter",
	"BAAAADJ1YsiUNyn/P7sXjz8E4ILivstesQ46PWNRFQ": "Bloodletter",
	"BAAAADKZUgj0DCn/P4h6jz8E4ILivstWsQ4k5VQR8A": "Mind Sweeper",
	# Class mods: Siren
	"BAAAADLX7U6dESn/P4o2jz+voIHivvdu8iQR00y2sw": "Dragon",
	"BAAAADIH/PbzXyn/P7gkjz+voIHivvdm8iQKI4y3/A": "Flurrying Solitary Breaker",
	"BAAAADLZ1cazKyn/P9Bljz/Fo4Hivvd28iTELnw2/g": "Elementalist",
	# Class mods: Beastmaster
	"BAAAADJxar7sNin/PyI0jz+xqIHivq3G8ZvAJEyW9A": "DE4DEYE",
	"BAAAADJxbPbMNin/P0NMjz+xqIHivq3W8ZvG4NuUdQ": "Cosmic Stalker",
	"BAAAADLye/YsVin/P7mHjz/Mq4Hivq3O8ZskD6zXdA": "Bounty Hunter",
	"BAAAADJvaP5XOyn/P+JIj7/Oq4Hivq3e8RsP1XTx9Q": "Friend-Bot",
	# Unknown - class mod?
	"BAAAADJ4UhD6DCn/P9oUjz8E4ILivstWsQ4TydxXFg": "Mind Sweeper",
	# Eridian Artifacts
	"BAAAADJBioanWgvkbbMoC4EcgMor": "Grenadier Shock Stone",
	"BAAAADKMTxLBD3G/HbycLzvNRMXE5Rs": "Loaded Radiation Stone",
	"BAAAADJBioanWgvkbZ9iDYEcgFcU": "Quickdraw Electric Slide",
	"BAAAADJBioanWgvkbbcwDIEcgDoR": "Ravaging Radiation Stone",
	"BAAAADKRtBLBD3G/HbycAyuI5cXE5Rs": "Hasty Atom Balm",
	"BAAAADLIlRLBD3G/Hbycx0AYJsrE5Rs": "Spicy Radiodead",
	"BAAAADKgoBLBD3G/HbycGxmOZNHE5Rs": "Insulated Flesh Melter",
	"BAAAADLBH2F/JHOkf7X5VwkGNUYN9Ru8": "Road Warrior",
	"BAAAADLBK7d/JOWkf7X5V2GN46uM9hu8": "Radiodead Otto Idol",
	"BAAAADLB9ll/pDynf7X5V8VmA6tN9Ru8": "Spicy Spark Plug",

	# Unconfirmed weapon types
	"BAAAADLQUZD8nin/P5fKD+cQgMLCm5uCPD3J2qQ4qKGf1W0s310": "Itchy Laser-Sploder", # AR, I think?
	"BAAAADLRtJL/Gilfs5bKnB2cPvSvJDv3BgpXPBUz+RT0": "Oozing The Lob",
	"BAAAADKP9Jr/Gin/P9cMD4EKEEJ6E+s8Pm8QMq5u2W7D/t8": "Carrier",
	"BAAAADKP9Jr/Gin/P8cMD4FKUkJ6E+s8Pm8QEqZu2W7B/t8": "Carrier",
	"BAAAADKBvJL/Gin/D1HKD0OlAPwLfFqfTx4EshpQQg48gw": "Bitch",
	"BAAAADJFlpr3Gyn/P5fKwQEcgP6LZSXVzkUrkd+Kq9aHBH1w8Q": "Devoted",
	"BAAAADLBtO1pmpca59fpNJOYbpqFrDu9HA": "Overflowing", # Shield?
	"BAAAADJR9Zr/Gin/P9fMC4EA1UJ6Ind9PFeCP1KgKdcE9es": "Triple-Penetrating Critical Thug",
	"BAAAADLBtI0WmpcOq5frNJEGBIjB4Zm8HA": "Mesmer", # Nade?
	"BAAAADLddnJv2n0tf9fCD4EcgMJE4x+8WjOKxEIwuUfnvYWExP6yoRSv": "Pestilent Double-Bezoomy",
}

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
	raw = bogodecrypt(data.peek(), savetype)
	char = Protobufs.OakSave_pb2.Character() if savetype == "OakSaveGame" else Protobufs.OakProfile_pb2.Profile()
	char.ParseFromString(raw)
	if savetype == "BP_DefaultOakProfile_C":
		# There's not a lot interesting in the profile, so it's really just the banked items.
		# (Most of what's in the profile is your game settings and stuff.)
		for item in char.bank_inventory_list:
			obj = Item.from_serial(item)
			obj.seed = obj.level = 50
			ser = armor_serial(obj.serial())
			if ser in library: continue
			print('\t"%s": "%s",' % (ser, obj.get_title()))
		return
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

	# Your level isn't actually stored anywhere, only your XP.
	# This calculation might be wrong if you're precisely at a level,
	# due to rounding errors, but you'd have to basically be +/- 1 XP
	# from the level threshold - highly unlikely.
	level = int(((char.experience_points + 60) / 60) ** (1/2.8))

	# Money and Eridium are stored in what has to be a deliberately-obscured way, but
	# not very well encrypted. In char.inventory_category_list is an array of entries
	# which are identified by a "hash", and then a quantity. By inspecting my own save,
	# I deduce that money is the one with base_category_definition_hash 618814354, and
	# eridium has hash 3679636065. There's also one with hash 1413395216 which I think
	# I have none of on this save.
	money = eridium = "(unknown)" # Or should they default to zero?
	for inv in char.inventory_category_list:
		if inv.base_category_definition_hash == 618814354: money = inv.quantity
		if inv.base_category_definition_hash == 3679636065: eridium = inv.quantity
	print(char.preferred_character_name, "lvl", level, "cash", money, "eridium", eridium)
	slot = { }
	for eq in char.equipped_inventory_list:
		slot[eq.inventory_list_index] = eq.slot_data_path.split(".")[-1].removeprefix("BPInvSlot_")
	equipment = [None] * len(DISPLAY_ORDER)
	inventory = []
	for i, item in enumerate(char.inventory_items):
		obj = Item.from_serial(item.item_serial_number)
		# Flags seems to be a bitfield, 1 = "seen"?, 2 = starred, 4 = trashed?
		if args.library:
			obj.seed = obj.level = 50
			ser = armor_serial(obj.serial())
			if ser in library: continue
			if item.flags & 4: continue # Marked as Trash (I think)
			print('\t"%s": "%s",' % (ser, obj.get_title()))
			continue
		eq = slot.get(i)
		desc = "Lvl %d %s" % (obj.level, obj.get_title())
		if eq: equipment[DISPLAY_ORDER[eq]] = eq + ": " + desc
		else: inventory.append(desc)
	for obj in equipment:
		if obj: print(obj)
	for obj in inventory: print(obj)
	for serial in args.give.split(","):
		if not serial: continue
		serial, *changes = serial.split(":")
		obj = Item.from_serial(unarmor_serial(serial))
		if obj.seed == 50: obj.seed = random.randrange(1<<31) # Generate new seeds for library items
		obj.level = level
		for change in changes:
			if not change: pass
			if change[0].lower() == "l": obj.level = int(change[1:]) or level
		print("GIVE:", obj)
		item = Protobufs.OakSave_pb2.OakInventoryItemSaveGameData()
		item.item_serial_number = obj.serial()
		item.pickup_order_index = 0
		item.flags = 3 # starred?
		item.weapon_skin_path = ""
		char.inventory_items.append(item)
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
	data.append(bogoencrypt(raw, savetype))
	data = b"".join(data)
	with open(fn, "rb") as f: origdata = f.read()
	if data == origdata: print("SUCCESS")
	if args.save:
		with open("/tmp/BL3backup.sav", "wb") as f: f.write(origdata)
		with open(fn, "wb") as f: f.write(data)
		print("Saved.")

def main(args=None):
	parser = argparse.ArgumentParser(description="Borderlands 3 save file reader")
	parser.add_argument("-f", "--file", help="Specify an exact file name")
	parser.add_argument("--save", action="store_true", help="Write the file back")
	parser.add_argument("--steam-dir", help="Path to Steam library", default="~/.steam/steam")
	parser.add_argument("--steam-user", help="Steam user ID, or all or auto", default="auto")
	parser.add_argument("--files", help="File name pattern", default="*.sav")
	parser.add_argument("--library", action="store_true", help="List library IDs for all items")
	parser.add_argument("--give", default="", help="Add items to your inventory")
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
				# Special case: the profile is not a save file. Parse it only if getting a library dump.
				if save.name == "profile.sav" and not args.library: continue
				parse_savefile(save, args)

if __name__ == "__main__": main()
