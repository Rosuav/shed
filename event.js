import {lindt, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {ASIDE, H1, H2, MAIN, P, STYLE} = choc; //autoimport

const state = { };

export function render(data) {
	Object.assign(state, data);
	replace_content("body", [
		STYLE(`
body {display: flex; gap: 10px; width: 100%;}
main {flex: 1 1 0;}
aside {}
`),
		MAIN([
			H1("Hello, world"),
			P("Testing, testing"),
		]),
		ASIDE([
			H2("Two tabs go here"),
		]),
	]);
}
