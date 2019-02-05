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
	return data[:64]

dir = os.path.expanduser("~/.local/share/aspyr-media/borderlands 2/willowgame/savedata")
dir = os.path.join(dir, os.listdir(dir)[0]) # If this bombs, you might not have any saves
for fn in sorted(os.listdir(dir)):
	if not fn.endswith(".sav"): continue
	# if fn != "save000a.sav": continue # Hack: Use the smallest file available
	print(fn)
	try: print(parse_savefile(os.path.join(dir, fn)))
	except SaveFileFormatError as e: print(e.args[0])
