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
.buttonbox {display: flex; gap: 8px;}
.display {width: 850px;}
#maindisplay {width: 850px; height: 480px; background-size: contain; position: relative;}
#checkboxes input {width: 20px; height: 20px; position: absolute;}
#isactive-1 {left: 150px; top: 196px;}
#isactive-2 {left: 150px; top: 262px;}
#isactive-3 {left: 150px; top: 328px;}
#isactive-4 {left: 150px; top: 394px;}
#isactive-5 {left: 455px; top: 130px;}
#isactive-6 {left: 455px; top: 196px;}
#isactive-7 {left: 455px; top: 262px;}
#isactive-8 {left: 455px; top: 328px;}
#isactive-9 {left: 455px; top: 394px;}
ul {display: flex; list-style-type: none; padding-left: 0; gap: 8px;}
` + tabs.map(kwd => 'ul:not(:has([value="' + kwd.toLowerCase() + '"]:checked)) ~ #' + kwd.toLowerCase() + 'display {display: none;}').join("\n")));

export function render(data) {
	Object.assign(state, data);
	replace_content("body", [
		MAIN([
			H1("Hello, world"),
			P({class: "buttonbox"}, [
				BUTTON({class: "instant", "data-cmd": "rollout"}, state.rollout ? "Rolling out!" : "Roll out!"),
				BUTTON({class: "instant", "data-cmd": "enable"}, (state.enabled ? "Dis" : "En") + "able main actions"),
				BUTTON({class: "instant", "data-cmd": "activate"}, (state.activate ? "Dis" : "En") + "able reactivation"),
				BUTTON({class: "action", "data-action": "cycle"}, "[[ CYCLE ]]"), //TODO: Add a simpleconfirm or something
				BUTTON({class: "action", "data-action": "batchsize", "data-altaction": "batchback"}, "Batch size"),
				BUTTON({class: "action", "data-action": "cash_upgrades"}, "Cash upg"),
				BUTTON({class: "action", "data-action": "angel_upgrades"}, "Angel upg"),
				BUTTON({class: "action", "data-action": "managers"}, "Managers"),
				BUTTON({class: "action", "data-action": "pull"}, "Pull"),
			]),
			DIV({id: "maindisplay", style: "background-image: url(" + state.base_image || TRANSPARENT_IMAGE + ")"}, [
				DIV({id: "checkboxes"}, [1, 2, 3, 4, 5, 6, 7, 8, 9].map(idx =>
					INPUT({type: "checkbox", id: "isactive-" + idx, checked: state.active.includes(idx)}))),
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

//Holdin Shift uses the altaction instead of the action. But if there's no altaction, do the action.s
on("click", ".action", e => ws_sync.send({cmd: "enqueue", action: e.shiftPressed && e.match.dataset.altaction || e.match.dataset.action}));
on("click", "[name=imgsel]", e => curtab = e.match.value);
on("click", ".instant", e => ws_sync.send({cmd: e.match.dataset.cmd}));
on("click", "#checkboxes input", e => ws_sync.send({cmd: "active", idx: +e.match.id.replace("isactive-", ""), state: e.match.checked}));
