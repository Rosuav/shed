import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse
import os
import sys
from fuzzywuzzy import process, fuzz # ImportError? pip install 'fuzzywuzzy[speedup]'
import re

files = [unquote(urlparse(el.text).path)
		for el in ET.parse(sys.argv[1]).getroot()
			.findall(".//*/{http://xspf.org/ns/0/}location")
	]
pfx = len(os.path.commonprefix(files))
trimmed = [re.search(r" - ([^_]+)", f[pfx:]).group(1) for f in files]
for i, file in enumerate(files):
	others = trimmed[i + 1:] # Assume that similarity is commutative
	any = False
	for name, score in process.extractBests(trimmed[i], others, score_cutoff=80, scorer=fuzz.token_set_ratio):
		if not any:
			any = True
			print(file)
		print(name)
	if any: print("-----")
