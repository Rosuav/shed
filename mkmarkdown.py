import markdown
import xml.etree.ElementTree as ET

# Taking advantage of the existing attr_list extension here
from markdown.extensions.attr_list import AttrListTreeprocessor
class LinkAttrsTP(AttrListTreeprocessor):
	def run(self, element):
		super().run(element)
		for child in list(element.iter()):
			if child.tag == "a":
				# Two syntaxes: Links with attributes and buttons
				# [Link text](dest :.cls #id)
				# [Button text](:.cls #id)
				href, split, attrs = (" " + child.get("href", "")).partition(" :")
				if split:
					if href:
						# It's still a link. Add the attributes (and remove any loose whitespace)
						child.set("href", href.strip())
					else:
						# Make it a button.
						child.tag = "button"
						del child.attrib["href"]
						child.set("type", "button") # Can be overridden if needed eg [Apply](:type=submit)
					self.assign_attrs(child, attrs)

class LinkAttrs(markdown.extensions.Extension):
	def extendMarkdown(self, md):
		# Priority zero puts us last; increased priority will insert us ahead of
		# everything with lower priority. For this extension, running last is
		# best, as this allows us to take advantage of all the previous work.
		md.treeprocessors.register(LinkAttrsTP(md), "link_attrs", 0)

print(markdown.markdown("""# Hello, world!

* [Simple link](dest)
* [This is a link](to/here :.cls #someid)
* [Button](:.btn)

Sidebar
{:.sidebar}

""", extensions=[LinkAttrs()]))
