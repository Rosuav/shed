/* Chocolate Factory v0.4.4

DOM object builder. (Thanks to DeviCat for the name!)

Usage in HTML:
<script type=module src="https://rosuav.github.io/shed/chocfactory.js"></script>
<script defer src="/path/to/your/script.js"></script>

Usage in a module:
import choc, {set_content, on, DOM} from "https://rosuav.github.io/shed/chocfactory.js";


Once imported, the chocolate factory can be used in a number of ways:
* const {TAG} = choc; TAG(attr, contents) // recommended
* choc.TAG(attr, contents)
* choc("TAG", attr, contents)
* chocify("TAG"); TAG(attr, contents) // deprecated, non-module scripts only

Example:
const {FORM, LABEL, INPUT} = choc;
let el = FORM(LABEL(["Speak thy mind:", INPUT({name: "thought"})]))

Regardless of how it's called, choc will return a newly-created element with
the given tag, attributes, and contents. Both attributes and contents are
optional, but if both are given, must be in that order.

To replace the contents of a DOM element:
    set_content(element, contents);
The element can be either an actual DOM element or a selector. The contents
can be a DOM element (eg created by choc() above), or a text string, or an
array of elements and/or strings. Text strings will NOT be interpreted as
HTML, and thus can safely contain untrusted content. Note that this will
update a single element only, and will raise an error if multiple elements
match. (Changed in v0.2: Now raises if duplicates, instead of ignoring them.)

Hooking events can be done by selector. Internally this attaches the event
to the document, so dynamically-created objects can still respond to events.
    on("click", ".some-class", e => {console.log("Hello");});
To distinguish between multiple objects that potentially match, e.match
will be set to the object that received the event. (This is distinct from
e.target and e.currentTarget.) NOTE: e.match is wiped after the event
handler returns. For asynchronous use, capture it in a variable first.

For other manipulations of DOM objects, start by locating one by its selector:
    DOM('input[name="thought"]').value = "..."
This is like document.querySelector(), but ensures that there is only one
matching element, thus avoiding the risk of catching the wrong one. (It's also
shorter. Way shorter.)

If you use the <dialog> tag, consider fix_dialogs(). It adds basic support to
browsers which lack it, and can optionally provide automatic behaviour for
close buttons and/or clicking outside the dialog to close it.
    fix_dialogs({close_selector: "button.close,input[type=submit]"});
    fix_dialogs({click_outside: true});


The MIT License (MIT)

Copyright (c) 2020 Chris Angelico

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

export function DOM(sel) {
	const elems = document.querySelectorAll(sel);
	if (elems.length > 1) throw new Error("Expected a single element '" + sel + "' but got " + elems.length);
	return elems[0]; //Will return undefined if there are no matching elements.
}

export function set_content(elem, children) {
	if (typeof elem === "string") elem = DOM(elem);
	while (elem.lastChild) elem.removeChild(elem.lastChild);
	if (!Array.isArray(children)) children = [children];
	for (let child of children) {
		if (!child || child === "") continue;
		if (typeof child === "string" || typeof child === "number") child = document.createTextNode(child);
		elem.appendChild(child);
	}
	return elem;
}

const handlers = {};
export function on(event, selector, handler) {
	if (handlers[event]) return handlers[event].push([selector, handler]);
	handlers[event] = [[selector, handler]];
	document.addEventListener(event, e => {
		//Reimplement bubbling ourselves
		const top = e.currentTarget; //Generic in case we later allow this to attach to other than document
		let cur = e.target;
		while (cur && cur !== top) {
			e.match = cur; //We can't mess with e.currentTarget without synthesizing our own event object. Easier to make a new property.
			handlers[event].forEach(([s, h]) => cur.matches(s) && h(e));
			cur = cur.parentNode;
		}
		e.match = null; //Signal that you can't trust the match ref any more
	});
	return 1;
}

//Apply some patches to <dialog> tags to make them easier to use. Accepts keyword args in a config object:
//	fix_dialogs({close_selector: ".dialog_cancel,.dialog_close", click_outside: true});
//For older browsers, this adds showModal() and close() methods
//If cfg.close_selector, will hook events from all links/buttons matching it to close the dialog
//If cfg.click_outside, any click outside a dialog will also close it. (May not work on older browsers.)
export function fix_dialogs(cfg) {
	if (!cfg) cfg = {};
	//For browsers with only partial support for the <dialog> tag, add the barest minimum.
	//On browsers with full support, there are many advantages to using dialog rather than
	//plain old div, but this way, other browsers at least have it pop up and down.
	let need_button_fix = false;
	document.querySelectorAll("dialog").forEach(dlg => {
		if (!dlg.showModal) {
			dlg.showModal = function() {this.style.display = "block";}
			dlg.close = function(ret) {
				if (ret) this.returnValue = ret;
				this.style.removeProperty("display");
				this.dispatchEvent(new CustomEvent("close", {bubbles: true}));
			};
			need_button_fix = true;
		}
	});
	//Ideally, I'd like to feature-detect whether form[method=dialog] actually
	//works, and do this if it doesn't; we assume that the lack of a showModal
	//method implies this being also unsupported. New in Choc Factory 0.4.
	if (need_button_fix) on("click", 'dialog form[method="dialog"] button', e => {
		e.match.closest("dialog").close(e.match.value);
		e.preventDefault();
	});
	if (cfg.click_outside) on("click", "dialog", e => {
		//NOTE: Sometimes, clicking on a <select> will give spurious clientX/clientY
		//values. Since clicking outside is always going to send the message directly
		//to the dialog (not to one of its children), check for that case.
		if (e.match !== e.target) return;
		let rect = e.match.getBoundingClientRect();
		if (e.clientY < rect.top || e.clientY > rect.top + rect.height
				|| e.clientX < rect.left || e.clientX > rect.left + rect.width)
		{
			e.match.close();
			e.preventDefault();
		}
	});
	if (cfg.close_selector) on("click", cfg.close_selector, e => e.match.closest("dialog").close());
}

let choc = function(tag, attributes, children) {
	const ret = document.createElement(tag);
	//If called as choc(tag, children), assume all attributes are defaults
	if (typeof attributes === "string" || attributes instanceof Array || attributes instanceof Element)
		return set_content(ret, attributes);
	if (attributes) for (let attr in attributes) {
		if (attr.startsWith("data-")) //Simplistic - we don't transform "data-foo-bar" into "fooBar" per HTML.
			ret.dataset[attr.slice(5)] = attributes[attr];
		else if (attr === "form") //Setting the form attribute on an element has to be done differently.
			ret.setAttribute("form", attributes[attr]);
		else ret[attr] = attributes[attr];
	}
	if (children) set_content(ret, children);
	return ret;
}
choc.__version__ = "0.4.4";

//Interpret choc.DIV(attr, chld) as choc("DIV", attr, chld)
//This is basically what Python would do as choc.__getattr__()
choc = new Proxy(choc, {get: function(obj, prop) {
	if (prop in obj) return obj[prop];
	return obj[prop] = (a, c) => obj(prop, a, c);
}});

//For modules, make the main entry-point easily available.
export default choc;

//For non-module scripts, allow some globals to be used
window.choc = choc; window.set_content = set_content; window.on = on; window.DOM = DOM; window.fix_dialogs = fix_dialogs;
window.chocify = tags => tags.split(" ").forEach(tag => window[tag] = choc[tag]);
