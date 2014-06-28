# Proof of concept translation of ∅ into set(), except that it doesn't
# call the global name set(), it generates a BUILD_SET opcode with 0
# operands. AFAIK there's no way to generate that bytecode from normal
# Python source code, so this hand-rolls the bytecode and constructs a
# function based on that.

# I don't think this is particularly useful, but it's proof that such a
# translation is, theoretically at least, possible.
import dis
import opcode

source = """def empty_set_literal():
    print("I'm an empty set!",∅)
"""
source = """def count_word_lengths(words):
    s = ∅
    for w in words:
        s.add(len(w))
    return len(s)
"""

gl = {}
# TODO: Recognize the token as a token, not just a character.
# Note that the target string needs to be unique. Any use of this string will become an empty set.
marker = "∅ is set()"
exec(source.replace("∅",repr(marker)),gl)
names = list(gl.keys())
names.remove("__builtins__")
funcname = names[0] # Assumes exactly one function was created.
func = gl[funcname]
codeobj = func.__code__
markerpos = codeobj.co_consts.index(marker) # If this raises ValueError, we got a problem.

# With percent formatting of bytes, this would become rather easier
# Basically, what I want to do is reconstruct the original bytecode:
# the opcode, as a single byte, followed by the arg (if it's not None),
# as two bytes, little-endian. In Pike, that'd be sprintf("%-2c",instr.arg).
newcode = []
for instr in dis._get_instructions_bytes(codeobj.co_code):
	if instr.opname == 'LOAD_CONST' and instr.arg == markerpos:
		newcode.extend((opcode.opmap["BUILD_SET"], 0, 0))
		continue
	newcode.append(instr.opcode)
	if instr.arg is not None: newcode.extend((instr.arg%256, instr.arg//256))
newcode = bytes(newcode)
# Okay. We now should have a code object in which every assignment of our magic
# marker string has become a BUILD_SET with no args. Now we should be able to
# emit code that will generate the equivalent function. Note that removing the
# marker from co_consts might be dangerous if it's not last, so for the moment,
# just leave it be. This could be made a bit more readable with FunctionType
# and CodeType from the types module, but that'd mean polluting the target
# namespace, so I'll just fetch them from another function.
# Arguments to the code consructor. Could possibly fetch these by introspection.
# The one problem one is consts, which is named constants in the constructor.
args = ("argcount", "kwonlyargcount", "nlocals", "stacksize", "flags", "codestring",
	"consts", "names", "varnames", "filename", "name", "firstlineno",
	"lnotab", "freevars", "cellvars")
newsource = "{0} = type(lambda:0)(type((lambda:0).__code__)({1}), globals(), {0!r})".format(funcname,
	", ".join(repr(newcode if arg=='codestring' else getattr(codeobj, "co_"+arg)) for arg in args))
print(newsource)
