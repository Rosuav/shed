# Classify all HTML files by their copyright notices
# - None (no "Copyright" or "©" etc)
# - CC-BY-SA 4.0
# - All Rights Reserved
# - Other/Unknown
# As much as possible, find the exact beginning and end of the copyright
# notice, thus allowing them to be replaced as needed. But for now, just
# classify the files.
import os
from bs4 import BeautifulSoup

# root = "/home/rosuav/gsarchive/live"
root = "/home/rosuav/gsarchive/clone" # Faster and safer, not touching the original files

def classify(fn):
	...

for root, dirs, files in os.walk(root):
	print(fn, end="...\r")
	cr = classify(fn)
	print(fn, cr)
