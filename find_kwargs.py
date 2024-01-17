# Search Python files for cases where a parameter is set to itself
import ast
import os
import sys
from collections import defaultdict

fn = "(unknown)" # global because I'm lazy
stats = defaultdict(int)

class ParamFinder(ast.NodeVisitor):
	def visit_Call(self, node):
		matches = 0
		for arg in node.keywords:
			if (isinstance(arg.value, ast.Name) and
				# arg.value.ctx is Load # can't imagine how it would be otherwise
				arg.value.id == arg.arg):
					if "-q" not in sys.argv: print("%s:%d:%d: %s(%s=%s)" % (
						fn, node.lineno, node.col_offset,
						ast.unparse(node.func), arg.arg, arg.arg
					))
					matches += 1
		# For statistical purposes, it may also be of interest to count the
		# number of arguments, not just the number of calls.
		stats["Calls"] += 1
		if node.keywords: stats["Kwargs"] += 1
		if matches: stats["Matches"] += 1
		stats["MatchCount"] += matches
		stats["KwCount"] += len(node.keywords)
		stats["MaxMatch"] = max(stats["MaxMatch"], matches)
		stats["MaxKwargs"] = max(stats["MaxKwargs"], len(node.keywords))
	def visit_FunctionDef(self, node):
		stats["FunctionDefs"] += 1
		a = node.args
		stats["Params"] += (
			len(a.args) + len(a.kwonlyargs) + len(a.posonlyargs)
			+ bool(a.vararg) + bool(a.kwarg) # These are arg objects if there's a *a and/or a **kw, and None if not.
		)
		stats["ParamsKwPos"] += len(a.args)
		stats["ParamsKwOnly"] += len(a.kwonlyargs)
		stats["ParamsPosOnly"] += len(a.posonlyargs)

for root, dirs, files in os.walk("."):
	for fn in files:
		if fn.endswith(".py"):
			fn = os.path.join(root, fn)
			if "--no-test" in sys.argv and "test" in fn: continue
			with open(fn, "rb") as f:
				data = f.read()
			try:
				node = ast.parse(data)
			except Exception as e:
				print("Unable to parse", fn, file=sys.stderr)
				print(e, file=sys.stderr)
			ParamFinder().visit(node)

print()
if stats["Calls"]:
	print("Total function calls:", stats["Calls"])
	print("Calls with any kwarg:", stats["Kwargs"], "%.2f%%" % (stats["Kwargs"] / stats["Calls"] * 100.0))
	print("Maximum kwargs count:", stats["MaxKwargs"])
	print("Calls with any 'x=x':", stats["Matches"], "%.2f%%" % (stats["Matches"] / stats["Calls"] * 100.0))
	if stats["Kwargs"]:
		print(" - compared to kwarg:", stats["Matches"], "%.2f%%" % (stats["Matches"] / stats["Kwargs"] * 100.0))
		print("Maximum num of 'x=x':", stats["MaxMatch"])
		print("Total keyword params:", stats["KwCount"], "%.2f" % (stats["KwCount"] / stats["Calls"]), "per call")
		print("Num params where x=x:", stats["MatchCount"], "%.2f%%" % (stats["MatchCount"] / stats["KwCount"] * 100.0))
	if stats["FunctionDefs"]:
		print("Total function defns:", stats["FunctionDefs"])
		if not stats["Params"]: stats["Params"] = 1 # so that 0 out of 0 is 0%
		print("Function params: pos:", stats["ParamsPosOnly"], "%.2f%%" % (stats["ParamsPosOnly"] / stats["Params"] * 100.0))
		print("Function params: kwd:", stats["ParamsKwOnly"], "%.2f%%" % (stats["ParamsKwOnly"] / stats["Params"] * 100.0))
		print("Function params: any:", stats["ParamsKwPos"], "%.2f%%" % (stats["ParamsKwPos"] / stats["Params"] * 100.0))
