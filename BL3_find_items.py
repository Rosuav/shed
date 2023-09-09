# Parallel to BL1 and BL2 savefile readers. The name's a bit orphanned now.
# See https://github.com/FromDarkHell/BL3SaveEditor for a lot of great info.
import argparse
from BL1_find_items import FunctionArg, Consumable

class SaveFileFormatError(Exception): pass

def parse_savefile(fn):
	with open(fn, "rb") as f: data = Consumable(f.read())
	if data.get(4) != b"GVAS": raise SaveFileFormatError("Invalid magic number - corrupt file?")
	header = data.get(18) # Version numbers, various. Probably irrelevant.
	buildid = data.str()
	fmtver = data.int()
	# The keys are GUIDs and the meanings are opaque. I don't know if order is significant but let's preserve it.
	fmt = {data.get(16): data.int() for _ in range(data.int())}
	savetype = data.str()

def main(args=None):
	parser = argparse.ArgumentParser(description="Borderlands 3 save file reader")
	parser.add_argument("-f", "--file", help="Specify the file to parse")
	# TODO: Know the standard directory and go looking there
	args = parser.parse_args(args)
	print(args)
	if args.file: parse_savefile(args.file)

if __name__ == "__main__": main()
