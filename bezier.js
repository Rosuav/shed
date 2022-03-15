/* TODO

* Place control points and endpoints
* Draw Bezier curve
* Show stats about the curve
* Allow dragging of points to move them
* Allow insertion of points
* On mouseover, show cursor indicating draggability
* Controlled by tickbox: On hover, show the nearest point on the curve, and the lerps that get us there.

*/
import choc, {set_content, DOM, on} from "https://rosuav.github.io/shed/chocfactory.js";
const {INPUT, LABEL} = choc; //autoimport

const state = { };
const options = [
	{kwd: "allowdrag", lbl: "Allow drag", dflt: true},
	{kwd: "shownearest", lbl: "Show nearest", dflt: false},
];
set_content("#options", options.map(o => LABEL([INPUT({type: "checkbox", "data-kwd": o.kwd, checked: state[o.kwd] = o.dflt}), o.lbl])));
on("click", "#options input", e => state[e.match.dataset.kwd] = e.match.checked);

const canvas = DOM("canvas");
const ctx = canvas.getContext('2d');
const elements = [
	{type: "start", x: 600, y: 550},
	{type: "control", x: 600, y: 200},
	{type: "control", x: 200, y: 400},
	{type: "end", x: 200, y: 50},
	{type: "nearest", x: 600, y: 550, fixed: true}, //Can't be dragged around (moves autonomously when active)
];

const path_cache = { };
function element_path(name) {
	if (path_cache[name]) return path_cache[name];
	const path = new Path2D;
	path.arc(0, 0, 5, 0, 2*Math.PI);
	const crosshair_size = 8;
	path.moveTo(-crosshair_size, 0);
	path.lineTo(crosshair_size, 0);
	path.moveTo(0, -crosshair_size);
	path.lineTo(0, crosshair_size);
	path.closePath();
	return path_cache[name] = path;
}
let dragging = null, dragbasex = 50, dragbasey = 10;

function draw_at(ctx, el) {
	const path = element_path(el.type);
	ctx.save();
	ctx.translate(el.x|0, el.y|0);
	ctx.fillStyle = el.fillcolor || "#a0f0c080";
	ctx.fill(path);
	ctx.fillStyle = el.bordercolor || "#000000";
	ctx.stroke(path);
	ctx.restore();
}

function repaint() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	elements.forEach(el => el === dragging || draw_at(ctx, el));
	if (dragging) draw_at(ctx, dragging); //Anything being dragged gets drawn last, ensuring it is at the top of z-order.
	//HACK: Assume that (a) we have a cubic curve, (b) the start is the first element, (c) the next two are the
	//control points, and (d) the end is the fourth element.
	//I don't think the HTML5 Canvas can do anything higher-order than cubic, so if we support that, we might
	//have to replace all this with manual drawing anyway.
	const path = new Path2D;
	path.moveTo(elements[0].x, elements[0].y);
	path.bezierCurveTo(elements[1].x, elements[1].y, elements[2].x, elements[2].y, elements[3].x, elements[3].y);
	ctx.fillStyle = "#000000";
	ctx.stroke(path);
}
repaint();

function element_at_position(x, y, filter) {
	for (let el of elements) {
		if (filter && !filter(el)) continue;
		if (ctx.isPointInPath(element_path(el), x - el.x, y - el.y)) return el;
	}
}

canvas.addEventListener("pointerdown", e => {
	if (!state.allowdrag) return;
	if (e.button) return; //Only left clicks
	e.preventDefault();
	dragging = null;
	let el = element_at_position(e.offsetX, e.offsetY, el => !el.fixed);
	if (!el) return;
	e.target.setPointerCapture(e.pointerId);
	dragging = el; dragbasex = e.offsetX - el.x; dragbasey = e.offsetY - el.y;
});

canvas.addEventListener("pointermove", e => {
	if (!dragging) return;
	[dragging.x, dragging.y] = [e.offsetX - dragbasex, e.offsetY - dragbasey];
	repaint();
});

canvas.addEventListener("pointerup", e => {
	if (!dragging) return;
	e.target.releasePointerCapture(e.pointerId);
	[dragging.x, dragging.y] = [e.offsetX - dragbasex, e.offsetY - dragbasey];
	dragging = null;
	repaint();
});
