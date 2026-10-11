import {lindt, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {H1, P} = choc; //autoimport

const state = { };

export function render(data) {
	Object.assign(state, data);
	replace_content("body", [
		H1("Hello, world"),
		P("Testing, testing"),
	]);
}
