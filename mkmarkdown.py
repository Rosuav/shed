import markdown
import xml.etree.ElementTree as ET

# TODO: Iterate over some directory, loading the templates from it
# For now, hard-coding this one simple template.
templates = {
	"default.html": """<!DOCTYPE HTML>
<html lang=en>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$$title$$</title>
<link rel="stylesheet" href="styles.css">
<link rel="icon" href="siteicon.png">
$$head_scripts$$</head>
<body><main>$$content$$</main></body>
</html>
""",
}

# This would come from the database, or be directly provided by the user during
# editing. For now, simple example.
page = """\
script: foo.js foo.css

# Hello, world

* [Simple link](dest)
* [This is a link](to/here :.cls #someid)
* [Button](:.btn)

Sidebar
{:tag=aside}

"""

# Taking advantage of the existing attr_list extension here
from markdown.extensions.attr_list import AttrListTreeprocessor
class LinkAttrsTP(AttrListTreeprocessor):
	def run(self, element):
		super().run(element)
		self.md.first_heading = None
		for child in list(element.iter()):
			if child.tag == "h1":
				if self.md.first_heading is None:
					self.md.first_heading = child.text
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

	def assign_attrs(self, elem, *a, **kw):
		ret = super().assign_attrs(elem, *a, **kw)
		# Post-process to check if there's a tag attribute, in which case we
		# replace the tag with that: *42*{:tag=output}
		tag = elem.get("tag")
		if tag:
			del elem.attrib["tag"]
			elem.tag = tag
		return ret

class LinkAttrs(markdown.extensions.Extension):
	def extendMarkdown(self, md):
		# Priority zero puts us last; increased priority will insert us ahead of
		# everything with lower priority. For this extension, running last is
		# best, as this allows us to take advantage of all the previous work.
		md.treeprocessors.register(LinkAttrsTP(md), "link_attrs", 0)

md = markdown.Markdown(extensions=["meta", LinkAttrs()])
html = md.convert(page)
sitetitle = md.Meta.get("sitetitle", "Example Site")
title = md.Meta.get("title") or (md.first_heading,)
title = " ".join(title) + " - " + sitetitle if title else sitetitle
def make_script(fn):
	if fn.endswith(".js"):
		return "<script type=module src=\"" + fn + "\"></script>"
	if fn.endswith(".css"):
		return "<link rel=\"stylesheet\" href=\"" + fn + "\">"
	return "<!-- unknown script " + fn + "-->"

head_scripts = "".join(make_script(fn) for line in md.Meta.get("script", []) for fn in line.split())
template = "".join(md.Meta.get("template", ["default.html"]))
if template not in templates:
	# TODO: Throw some kind of error, or at least a warning
	template = "default.html"
output = (templates[template]
	.replace("$$title$$", title)
	.replace("$$head_scripts$$", head_scripts)
	.replace("$$content$$", html)
)
print(output)
