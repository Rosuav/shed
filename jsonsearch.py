# TODO: Parameterize. Pass a JSON file name, a JSON blob, or no argument to read stdin.
import json
import sys

with open("eu4_parse.json") as f: data = json.load(f)

def search(node, term, path):
	if isinstance(node, dict): items = node.items()
	elif isinstance(node, list): items = enumerate(node)
	elif term in str(node):
		print("->".join(path) + ":", node)
		return
	else: return
	for k, v in items:
		search(v, term, path + (str(k),))

search(data, sys.argv[1], ())
