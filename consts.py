import dis
import opcode

class InvalidConstantError(Exception): pass

def const(**names):
	"""Decorator to rewrite lookups to be constants

	@const(x=1)
	def func():
		print(x) # prints 1
	"""
	def decorate(func):
		# Constants are not allowed to be assigned to within the function.
		# Thus they should never appear in the function's local names.
		# TODO: Alter the message if the colliding name is an argument.
		c = func.__code__
		if set(names) & set(c.co_varnames):
			raise InvalidConstantError("Cannot assign to local constant")

		# Constants should not be declared nonlocal and then assigned to.
		# (Unfortunately this doesn't actually check if they were assigned to.)
		if set(names) & set(c.co_freevars):
			raise InvalidConstantError("Cannot create local and nonlocal constant")

		# Constants should therefore be global names.
		if set(names) - set(c.co_names):
			raise InvalidConstantError("Constant not referenced as global")

		# Okay. So now we replace every LOAD_GLOBAL for one of these names
		# with a LOAD_CONST.
		newcode = []
		newconsts = c.co_consts
		for name, val in names.items():
			try:
				names[name] = newconsts.index(val)
			except ValueError:
				names[name] = len(newconsts)
				newconsts += (val,)
		LOAD_CONST = opcode.opmap["LOAD_CONST"]
		for instr in dis.get_instructions(c):
			if instr.opname == "LOAD_GLOBAL" and instr.argval in names:
				newcode.append(LOAD_CONST)
				newcode.append(names[instr.argval])
			else:
				newcode.append(instr.opcode)
				newcode.append(instr.arg or 0)

		codeobj = type(c)(c.co_argcount, c.co_kwonlyargcount, c.co_nlocals, c.co_stacksize,
			c.co_flags, bytes(newcode), newconsts, c.co_names, c.co_varnames, c.co_filename,
			c.co_name, c.co_firstlineno, c.co_lnotab, c.co_freevars, c.co_cellvars)

		func = type(func)(codeobj, func.__globals__, func.__name__, func.__defaults__, func.__closure__)

		return func
	return decorate

x = "global"
@const(x=1)
def func():
	print("This should be one:", x)
func()

try:
	@const(x=1)
	def func(x):
		print("Shouldn't happen")
	func(2)
except InvalidConstantError as e:
	print(e)

try:
	@const(x=1)
	def func():
		x = 2
		print("Shouldn't happen")
	func()
except InvalidConstantError as e:
	print(e)

try:
	def f():
		x = 2
		@const(x=1)
		def func():
			nonlocal x
			print("Shouldn't happen")
		return func
	f()
except InvalidConstantError as e:
	print(e)

@const(len=len, str=str, int=int)
def digit_count(n):
	return len(str(int(n)))

dis.dis(digit_count)
