# Parallel to BL1 and BL2 savefile readers. The name's a bit orphanned now.
# See https://github.com/FromDarkHell/BL3SaveEditor for a lot of great info.
import argparse
from BL1_find_items import FunctionArg, Consumable

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
	print(raw[:256])

def main(args=None):
	parser = argparse.ArgumentParser(description="Borderlands 3 save file reader")
	parser.add_argument("-f", "--file", help="Specify the file to parse")
	# TODO: Know the standard directory and go looking there
	args = parser.parse_args(args)
	print(args)
	if args.file: parse_savefile(args.file)

if __name__ == "__main__": main()
