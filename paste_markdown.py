# Watch the clipboard for formatted text (eg from LibreOffice) and convert it into Markdown.
# Will put the markdown back onto the clipboard.
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk
from bs4 import BeautifulSoup

def soup_to_markdown(soup):
	md = ""
	for child in soup:
		if isinstance(child, str):
			md += child.replace("\n", " ")
			continue
		md += soup_to_markdown(child)
	# Depending on the tag, manage whitespace
	if soup.name in ["p", "body"]:
		return md.strip() + "\n\n"
	if soup.name in ["i", "em"]:
		return "*" + md + "*"
	if soup.name in ["b", "strong"]:
		return "**" + md + "**"
	if soup.name == "img":
		# Ignore any contents, there should be none.
		return "![" + (soup.get("alt") or soup["name"]) + "](" + soup["src"] + ")"
	return md

def got_data(clip, data):
	print("Got data!")
	soup = BeautifulSoup(data.get_data(), "html5lib")
	md = soup_to_markdown(soup.body)
	clip.set_text(md, -1)

def copied(clip, ev):
	# NOTE: If you don't wait_for_targets, the request for text/html format might succeed,
	# but the contents is blank. It's safest to wait and see.
	ok, targ = clip.wait_for_targets()
	for t in targ:
		if t.name() == "text/html":
			clip.request_contents(t, got_data)
			break

Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).connect("owner_change", copied)
Gtk.main()
