/* TODO

* Place control points and endpoints
* Draw Bezier curve
* Show stats about the curve
* Allow dragging of points to move them
* Allow insertion of points
* On mouseover, show cursor indicating draggability

*/
import choc, {set_content, DOM, on} from "https://rosuav.github.io/shed/chocfactory.js";
const {BUTTON, DIV, LABEL, INPUT, SELECT, OPTION, TR, TD, TEXTAREA, LI, CODE} = choc; //autoimport

const canvas = DOM("canvas");
const ctx = canvas.getContext('2d');
const elements = [
	{type: "start", x: 500, y: 550},
	{type: "end", x: 300, y: 50},
	{type: "control", x: 500, y: 300},
	{type: "control", x: 300, y: 300},
];

//TODO: Design a nice path for a grabbable marker (maybe a circle with crosshair?)
//Unlike this stub, it should be centered around (0,0).
const path_cache = { };
function element_path(name) {
	if (path_cache[name]) return path_cache[name];
	const path = new Path2D;
	path.moveTo(0, 0);
	path.lineTo(10, 0);
	path.lineTo(10, 10);
	path.lineTo(0, 10);
	path.lineTo(0, 10);
	path.closePath();
	return path_cache[name] = path;
}
let dragging = null, dragbasex = 50, dragbasey = 10;

function draw_at(ctx, el) {
	const path = element_path(el.type);
	ctx.save();
	ctx.translate(el.x|0, el.y|0);
	ctx.fillStyle = el.color || "#000000";
	ctx.fill(path);
	ctx.fillStyle = "black";
	ctx.stroke(path);
	ctx.restore();
}

function repaint() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	elements.forEach(el => el === dragging || draw_at(ctx, el));
	if (dragging) draw_at(ctx, dragging); //Anything being dragged gets drawn last, ensuring it is at the top of z-order.
	//TODO: Draw the Bezier curve joining these points
}
repaint();

function element_at_position(x, y, filter) {
	for (let el of elements) {
		if (filter && !filter(el)) continue;
		if (ctx.isPointInPath(element_path(el), x - el.x, y - el.y)) return el;
	}
}

canvas.addEventListener("pointerdown", e => {
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
