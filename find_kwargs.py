# Search Python files for cases where a parameter is set to itself
import ast
import os
import sys
from collections import defaultdict

fn = "(unknown)" # global because I'm lazy
stats = defaultdict(int)

class ParamFinder(ast.NodeVisitor):
	def visit_Call(self, node):
		matches = False
		for arg in node.keywords:
			if (isinstance(arg.value, ast.Name) and
				# arg.value.ctx is Load # can't imagine how it would be otherwise
				arg.value.id == arg.arg):
					print("%s:%d:%d: %s(%s=%s)" % (
						fn, node.lineno, node.col_offset,
						ast.unparse(node.func), arg.arg, arg.arg
					))
					matches = True
		# For statistical purposes, it may also be of interest to count the
		# number of arguments, not just the number of calls.
		stats["Calls"] += 1
		if node.keywords: stats["Kwargs"] += 1
		if matches: stats["Matches"] += 1

for root, dirs, files in os.walk("."):
	for fn in files:
		if fn.endswith(".py"):
			fn = os.path.join(root, fn)
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
	print("Calls with any 'x=x':", stats["Matches"], "%.2f%%" % (stats["Matches"] / stats["Calls"] * 100.0))
	if stats["Kwargs"]: print(" - compared to kwarg:", stats["Matches"], "%.2f%%" % (stats["Matches"] / stats["Kwargs"] * 100.0))

