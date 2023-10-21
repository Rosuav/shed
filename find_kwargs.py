# Search Python files for cases where a parameter is set to itself
import ast
import os
import sys

fn = "(unknown)" # global because I'm lazy
class ParamFinder(ast.NodeVisitor):
	def visit_Call(self, node):
		for arg in node.keywords:
			if (isinstance(arg.value, ast.Name) and
				# arg.value.ctx is Load # can't imagine how it would be otherwise
				arg.value.id == arg.arg):
					print("%s:%d:%d: %s(%s=%s)" % (
						fn, node.lineno, node.col_offset,
						ast.unparse(node.func), arg.arg, arg.arg
					))

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
