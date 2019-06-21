/* Chocolate Factory v0.1

DOM object builder. (Thanks to DeviCat for the name!)

Usage in HTML:
<script type=module src="https://rosuav.github.io/shed/chocfactory.js"></script>
<script src="/path/to/your/script.js"></script>

Usage in a module:
import choc, {set_content} from "https://rosuav.github.io/shed/chocfactory.js";

chocify("UL LI FORM INPUT");
const {UL, LI, FORM, INPUT} = choc;

TODO: Document this. Because docs.

The MIT License (MIT)

Copyright (c) 2019 Chris Angelico

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

export function set_content(elem, children) {
	//TODO: If elem is a selector, look it up
	while (elem.lastChild) elem.removeChild(elem.lastChild);
	if (!Array.isArray(children)) children = [children];
	for (let child of children) {
		if (!child || child === "") continue;
		if (typeof child === "string") child = document.createTextNode(child);
		elem.appendChild(child);
	}
	return elem;
}

let choc = function(tag, attributes, children) {
	const ret = document.createElement(tag);
	if (attributes) for (let attr in attributes) {
		if (attr.startsWith("data-")) //Simplistic - we don't transform "data-foo-bar" into "fooBar" per HTML.
			ret.dataset[attr.slice(5)] = attributes[attr];
		else ret[attr] = attributes[attr];
	}
	if (children) set_content(ret, children);
	return ret;
}

//Interpret choc.DIV(attr, chld) as choc("DIV", attr, chld)
//This is basically what Python would do as choc.__getattr__()
choc = new Proxy(choc, {get: function(obj, prop) {
	if (prop in obj) return obj[prop];
	return obj[prop] = (a, c) => obj(prop, a, c);
}});

//For modules, make the main entry-point easily available.
export default choc;

//For non-module scripts, allow some globals to be used
window.choc = choc; window.set_content = set_content;
window.chocify = tags => tags.split(" ").forEach(tag => window[tag] = choc[tag]);
window.chocify("BUTTON DIV IMG INPUT LABEL LI TD TR SELECT OPTION"); //Deprecated set of defaults
