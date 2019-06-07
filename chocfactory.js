/* Chocolate Factory v0.1

DOM object builder. (Thanks to DeviCat for the name!)

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

function set_content(elem, children) {
	while (elem.lastChild) elem.removeChild(elem.lastChild);
	if (!Array.isArray(children)) children = [children];
	for (let child of children) {
		if (!child || child === "") continue;
		if (typeof child === "string") child = document.createTextNode(child);
		elem.appendChild(child);
	}
	return elem;
}

function choc(tag, attributes, children) {
	const ret = document.createElement(tag);
	if (attributes) for (let attr in attributes) {
		if (attr.startsWith("data-")) //Simplistic - we don't transform "data-foo-bar" into "fooBar" per HTML.
			ret.dataset[attr.slice(5)] = attributes[attr];
		else ret[attr] = attributes[attr];
	}
	if (children) set_content(ret, children);
	return ret;
}
//TODO: Enumerate these somehow
"BUTTON DIV IMG INPUT LABEL LI TD TR"
	.split(" ").forEach(tag => window[tag] = (a, c) => choc(tag, a, c));
