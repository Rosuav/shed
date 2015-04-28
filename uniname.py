import sys, unicodedata
for ch in sys.argv[1]: print(ascii(ch), unicodedata.name(ch))
