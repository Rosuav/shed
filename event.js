import {lindt, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {ASIDE, BR, BUTTON, DIV, H1, H2, IMG, INPUT, LABEL, LI, MAIN, P, UL} = choc; //autoimport

const state = { };
const TRANSPARENT_IMAGE = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNgAAIAAAUAAen63NgAAAAASUVORK5CYII=";
const tabs = ["Goals", "Angels"];
let curtab = "goals";
document.head.append(choc.STYLE(`
* {box-sizing: border-box;}
body {display: flex; gap: 10px;}
main {flex: 1 1 0;}
aside {flex: 0 1 auto;}
.display {width: 850px;}
#maindisplay {width: 850px; height: 480px; background-size: contain;}
ul {display: flex; list-style-type: none; padding-left: 0; gap: 8px;}
` + tabs.map(kwd => 'ul:not(:has([value="' + kwd.toLowerCase() + '"]:checked)) ~ #' + kwd.toLowerCase() + 'display {display: none;}').join("\n")));

export function render(data) {
	Object.assign(state, data);
	replace_content("body", [
		MAIN([
			H1("Hello, world"),
			P(BUTTON({id: "rollout"}, "Roll out!")),
			DIV({id: "maindisplay", style: "background-image: url(" + state.base_image || TRANSPARENT_IMAGE + ")"}, [
				"overlaid text example",
			]),
		]),
		ASIDE([
			H2("Two tabs go here"),
			UL(tabs.map(kwd => LI(LABEL([INPUT({type: "radio", name: "imgsel", value: kwd.toLowerCase(), checked: kwd.toLowerCase() === curtab}), kwd])))),
			tabs.map(kwd => DIV({id: kwd.toLowerCase() + "display"}, [
				BUTTON({class: "action", "data-action": kwd.toLowerCase()}, "Refresh"), BR(),
				IMG({class: "display", src: state[kwd.toLowerCase() + "_image"] || TRANSPARENT_IMAGE}),
			])),
		]),
	]);
}

on("click", ".action", e => ws_sync.send({cmd: "enqueue", action: e.match.dataset.action}));
on("click", "[name=imgsel]", e => curtab = e.match.value);
on("click", "#rollout", e => ws_sync.send({cmd: "rollout"}));
