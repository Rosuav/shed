# Read a VLC playlist in xspf format and shuffle it. Compared to
# using the "shuffle" mode, this has the advantage that it can be
# browsed in the playlist - you can see the next and previous, etc.
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse
import os
import sys
import random

files = [unquote(urlparse(el.text).path)
		for el in ET.parse(sys.argv[1]).getroot()
			.findall(".//*/{http://xspf.org/ns/0/}location")
	]
random.shuffle(files)
os.execvp("vlc", files)
