import {choc, DOM, on} from "https://rosuav.github.io/choc/factory.js";
const {STYLE} = choc; //autoimport

DOM("#trace").onmousemove = e => {
	const cls = [];
	for (let elem = e.target; elem.id !== "trace"; elem = elem.parentElement)
		cls.push("show-" + elem.className);
	document.body.className = cls.join(" ");
}
DOM("#trace").onmouseleave = e => document.body.className = "show-default";

const colors = {
	cmd: "#fbf",
	hdr: "#9ff",
	dest: "#ffa",
	early: "#fce",
	poem: "#ecf",
	arrival: "#cef",
	index: "#dfd",
	hop: "#fe9",
	hidden: "#f88",
	time: "#bbf",
	line: "#bfb",
	ip: "#fe9",
	landing: "#ffa",
};

DOM("#explanations").innerText = Object.entries(colors).map(([id, col]) =>
	"body:not(.show-" + id + ") #expl-" + id + " {display: none;}\n" +
	"body.show-" + id + " #trace span." + id + " {background: " + col + ";}\n" +
	"#expl-" + id + " {background: " + col + "; width: fit-content;}"
).join("\n");
