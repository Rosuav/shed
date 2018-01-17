# Reimplementation of the Steam Mobile Authentication protocol, as demonstrated
# by https://github.com/geel9/SteamAuth (MIT-licensed, as is this code).

def do_code(user):
	"""Generate an auth code for logins"""
	print("Stub, unimplemented")

def do_trade(user):
	"""Accept all pending trades/markets"""
	print("Stub, unimplemented")

def do_setup(user):
	"""Set up a new user"""
	print("Stub, unimplemented")

def usage():
	print("USAGE: python3 steamguard.py [command] [user]")
	print("command is one of:")
	for func in sorted(globals()):
		if func.startswith("do_"):
			doc = globals()[func].__doc__.split("\n")[0]
			print("%-10s %s" % (func[3:], doc))
	print("user is the name of the Steam account to use - optional if")
	print("only one account is registered with this app.")
	return 1

def main(args):
	func = do_code
	user = None
	for arg in args:
		f = globals().get("do_" + arg)
		if f:
			if func: return usage()
			func = f
		else:
			if user: return usage()
			user = arg
	if not user:
		print("TODO: check if there's exactly one user, and if so,")
		print("default to that user. Not yet implemented.")
	func(user)

if __name__ == "__main__":
	import sys
	sys.exit(main(sys.argv[1:]))
