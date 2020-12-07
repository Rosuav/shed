# Encode and decode CS:GO match sharing codes
# See: https://github.com/akiver/CSGO-Demos-Manager/blob/7abb325ad3663732ca585addee52383a78751314/Core/ShareCode.cs#L79

DICTIONARY = "ABCDEFGHJKLMNOPQRSTUVWXYZabcdefhijkmnopqrstuvwxyz23456789"

def encode(match, outcome, port):
	b = match.to_bytes(8, "little") + outcome.to_bytes(8, "little") + port.to_bytes(2, "little")
	n = int.from_bytes(b, "big")
	print(hex(n))
	# Again, this looks like a straight-forward base-57 encode, I think
	code = ""
	for _ in range(25):
		code += DICTIONARY[n % len(DICTIONARY)]
		n //= len(DICTIONARY)
	return code

def decode(sharecode):
	if "CSGO-" not in sharecode: raise Exception("Not a share code")
	sharecode = sharecode.split("CSGO-", 1)[1].replace("-", "")
	# Looks like just a base-57 decode?
	n = 0
	for c in sharecode[::-1]:
		n = n * len(DICTIONARY) + DICTIONARY.find(c)
	# Convert n to a byte array, then split it up
	# First eight bytes are the match ID, next eight are the outcome ID, then two bytes for the port ID
	# There seems to be an endianness change too.
	print(hex(n))
	b = n.to_bytes(8+8+2, "big")
	match_id = int.from_bytes(b[:8], "little")
	outcome = int.from_bytes(b[8:16], "little")
	port = int.from_bytes(b[16:], "little")
	return match_id, outcome, port
