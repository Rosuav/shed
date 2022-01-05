#!/usr/bin/env python3
import sys, unicodedata
for ch in " ".join(sys.argv[1:]): print(ascii(ch), unicodedata.name(ch))
#TODO: Unicode variant analyzer
#- Accept parameter which may or may not have a variant selector
#- Show the base character with every variant selector; highlight the one provided
#- Make it easy to copy/paste into a browser
#- There are technically sixteen, but skip 4-14 (FE03-FE0D) as they're not currently used
