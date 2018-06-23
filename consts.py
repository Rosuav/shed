import dis

class InvalidConstantError(Exception): pass

def const(**names):
	"""Decorator to rewrite lookups to be constants

	@const(x=1)
	def func():
		print(x) # prints 1
	"""
	def decorate(func):
		...
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
