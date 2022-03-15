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

const RESOLUTION = 256; //Spread this many points across the curve to do our calculations

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

function get_curve_points() {
	const ret = [null];
	let end = null;
	for (let el of elements) switch (el.type) {
		case "start": ret[0] = el; break;
		case "control": ret.push(el); break;
		case "end": end = el; break;
		default: break;
	}
	//assert ret[0] && end; //we need endpoints, even if we don't have any control points
	ret.push(end);
	return ret;
}

//Calculate {x: N, y: N} for the point on the curve at time t
const interpolation_factors = {
	4: t => [(1-t)**3, 3 * (1-t)**2 * t, 3 * (1-t) * t**2, t**3],
};
function interpolate(points, t) {
	const factors = interpolation_factors[points.length](t);
	let x = 0, y = 0;
	factors.forEach((f, i) => {x += points[i].x * f; y += points[i].y * f;});
	return {x, y};
}

function repaint() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	elements.forEach(el => el === dragging || (el.type === "nearest" && !state.shownearest) || draw_at(ctx, el));
	if (dragging) draw_at(ctx, dragging); //Anything being dragged gets drawn last, ensuring it is at the top of z-order.
	//I don't think the HTML5 Canvas can do anything higher-order than cubic, so if we support that, we might
	//have to replace all this with manual drawing anyway.
	//Is it possible to subdivide a higher-order curve into segments and then approximate those with cubic curves??
	//Otherwise, just subdivide into *very* short segments and approximate those with lines.
	const points = get_curve_points();
	const path = new Path2D;
	const method = {2: "lineTo", 3: "quadraticCurveTo", 4: "bezierCurveTo"}[points.length];
	if (!method) return; //Maybe we need to render manually?
	path.moveTo(points[0].x, points[0].y); points.shift();
	const coords = [];
	points.forEach(p => coords.push(p.x, p.y));
	path[method](...coords);
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
	if (dragging) {
		[dragging.x, dragging.y] = [e.offsetX - dragbasex, e.offsetY - dragbasey];
		repaint();
	}
	if (state.shownearest) {
		const points = get_curve_points();
		let best = {x:0, y:0}, bestdist = -1;
		for (let t = 0; t <= 1; t += 1/RESOLUTION) {
			const p = interpolate(points, t);
			const dist = (p.x - e.offsetX) ** 2 + (p.y - e.offsetY) ** 2;
			if (bestdist < 0 || dist < bestdist) {bestdist = dist; best = p;}
		}
		const nearest = elements.find(el => el.type === "nearest");
		nearest.x = best.x; nearest.y = best.y;
		repaint();
	}
});

canvas.addEventListener("pointerup", e => {
	if (!dragging) return;
	e.target.releasePointerCapture(e.pointerId);
	[dragging.x, dragging.y] = [e.offsetX - dragbasex, e.offsetY - dragbasey];
	dragging = null;
	repaint();
});
