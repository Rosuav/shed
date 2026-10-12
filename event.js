import {lindt, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {ASIDE, BUTTON, DIV, H1, H2, IMG, INPUT, LABEL, LI, MAIN, P, STYLE, UL} = choc; //autoimport

const state = { };
const TRANSPARENT_IMAGE = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNgAAIAAAUAAen63NgAAAAASUVORK5CYII=";
const tabs = ["Goals", "Angels"];
let curtab = "goals";

export function render(data) {
	Object.assign(state, data);
	replace_content("body", [
		STYLE(`
* {box-sizing: border-box;}
body {display: flex; gap: 10px;}
main {flex: 1 1 0;}
aside {flex: 0 1 auto;}
ul {display: flex; list-style-type: none; padding-left: 0; gap: 8px;}
` + tabs.map(kwd => "ul:not(:has(#" + kwd.toLowerCase() + ":checked)) ~ #" + kwd.toLowerCase() + "display {display: none;}").join("\n")),
		MAIN([
			H1("Hello, world"),
			P(BUTTON({id: "rollout"}, "Roll out!")),
			IMG({src: state.base_image || TRANSPARENT_IMAGE}),
		]),
		ASIDE([
			H2("Two tabs go here"),
			UL(tabs.map(kwd => LI(LABEL([INPUT({type: "radio", name: "imgsel", value: kwd.toLowerCase(), checked: kwd.toLowerCase() === curtab}), kwd])))),
			tabs.map(kwd => DIV({id: kwd.toLowerCase() + "display"}, [
				BUTTON({class: "action", "data-action": kwd.toLowerCase()}, kwd),
				IMG({src: state.goals_image || TRANSPARENT_IMAGE}),
			])),
		]),
	]);
}

on("click", ".action", e => ws_sync.send({cmd: "action", action: e.match.dataset.action}));
on("click", "[name=imgsel]", e => curtab = e.match.value);
on("click", "#rollout", e => ws_sync.send({cmd: "rollout"}));
