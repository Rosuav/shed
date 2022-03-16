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
const {INPUT, LABEL, SPAN} = choc; //autoimport

const RESOLUTION = 256; //Spread this many points across the curve to do our calculations

const state = { };
const options = [
	{kwd: "allowdrag", lbl: "Allow drag", dflt: true},
	{kwd: "shownearest", lbl: "Show nearest", dflt: false},
	{kwd: "shownearestlines", lbl: "... with lines", dflt: false, depend: "shownearest"},
	{kwd: "shownearestvectors", lbl: "... with vectors", dflt: false, depend: "shownearest"},
	{kwd: "shownearestcircle", lbl: "... and circle", dflt: false, depend: "shownearestvectors"},
];
set_content("#options", options.map(o => LABEL([INPUT({type: "checkbox", "data-kwd": o.kwd, checked: state[o.kwd] = o.dflt}), o.lbl])));
const _optlookup = { };
options.forEach(o => {_optlookup[o.kwd] = o; o.rdepend = []; if (o.depend) _optlookup[o.depend].rdepend.push(o.kwd);});
on("click", "#options input", e => {
	state[e.match.dataset.kwd] = e.match.checked;
	if (e.match.checked) {
		//Ensure that dependencies are also checked.
		let o = _optlookup[e.match.dataset.kwd];
		while (o.depend && !state[o.depend]) {
			DOM("[data-kwd=" + o.depend + "]").checked = state[o.depend] = true;
			o = _optlookup[o.depend];
		}
	} else {
		function cleartree(kwd) {
			if (state[kwd]) DOM("[data-kwd=" + kwd + "]").checked = state[kwd] = false;
			_optlookup[kwd].rdepend.forEach(cleartree);
		}
		cleartree(e.match.dataset.kwd);
	}
	repaint();
});

const canvas = DOM("canvas");
const ctx = canvas.getContext('2d');
const elements = [
	{type: "start", x: 600, y: 550},
	{type: "control", x: 600, y: 200},
	{type: "control", x: 200, y: 400},
	{type: "end", x: 200, y: 50},
];
let highlight_t_value = 0.0;

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
	ctx.strokeStyle = el.bordercolor || "#000000";
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
	1: t => [1],
	2: t => [1 - t, t],
	3: t => [(1-t)**2, 2 * (1-t)**1 * t, t**2],
	4: t => [(1-t)**3, 3 * (1-t)**2 * t, 3 * (1-t) * t**2, t**3],
};
function interpolate(points, t) {
	const factors = interpolation_factors[points.length](t);
	let x = 0, y = 0;
	factors.forEach((f, i) => {x += points[i].x * f; y += points[i].y * f;});
	return {x, y};
}

const lerp_colors = ["#00000080", "#ee2222", "#11aa11", "#2222ee"];
function repaint() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	elements.forEach(el => el === dragging || draw_at(ctx, el));
	//I don't think the HTML5 Canvas can do anything higher-order than cubic, so if we support that, we might
	//have to replace all this with manual drawing anyway.
	//Is it possible to subdivide a higher-order curve into segments and then approximate those with cubic curves??
	//Otherwise, just subdivide into *very* short segments and approximate those with lines.
	ctx.save();
	const points = get_curve_points();
	const path = new Path2D;
	const method = {2: "lineTo", 3: "quadraticCurveTo", 4: "bezierCurveTo"}[points.length];
	if (!method) return; //Maybe we need to render manually?
	const coords = [];
	points.forEach(p => coords.push(p.x, p.y));
	path.moveTo(coords.shift(), coords.shift());
	path[method](...coords);
	ctx.strokeStyle = "#000000";
	ctx.stroke(path);
	ctx.restore();
	if (state.shownearest) {
		//Highlight a point near to the mouse cursor
		const t = highlight_t_value, curve_at_t = interpolate(points, highlight_t_value);
		if (state.shownearestlines) {
			//Show the lerp lines
			let ends = points;
			while (ends.length > 1) {
				//For every pair of points, draw the line, and retain the position t
				//of the way through that line as the next point.
				ctx.save();
				const path = new Path2D;
				path.moveTo(ends[0].x, ends[0].y);
				const mids = [];
				for (let i = 1; i < ends.length; ++i) {
					path.lineTo(ends[i].x, ends[i].y);
					mids.push({
						x: ends[i-1].x * (1-t) + ends[i].x * t,
						y: ends[i-1].y * (1-t) + ends[i].y * t,
					});
				}
				ctx.strokeStyle = lerp_colors[points.length - ends.length];
				ctx.stroke(path);
				ctx.restore();
				ends = mids;
			}
		}
		if (state.shownearestvectors) {
			//Show the derivative vectors
			let deriv = points, factor = 1;
			let derivs = ["Derivatives at " + t.toFixed(3) + ": "];
			let d1 = null, d2 = null; //Track the first and second derivatives for the sake of osculating circle calculation
			while (deriv.length > 1) {
				factor *= (deriv.length - 1); //The derivative is multiplied by the curve's degree at each step
				//The derivative of a curve is another curve with one degree lower,
				//whose points are all defined by the differences between other points.
				//This will tend to bring it close to zero, so it may not be viable to
				//draw the entire curve (unless we find a midpoint of some sort), but
				//we can certainly get a vector by taking some point on this curve.
				const nextcurve = [];
				for (let i = 1; i < deriv.length; ++i) {
					nextcurve.push({
						x: deriv[i].x - deriv[i - 1].x,
						y: deriv[i].y - deriv[i - 1].y,
					});
				}
				deriv = nextcurve;
				const d = interpolate(deriv, t);
				d.x *= factor; d.y *= factor; //Now it's the actual derivative at t.
				if (!d1) d1 = d;
				else if (!d2) d2 = d;
				const vector = {
					angle: Math.atan2(d.y, d.x),
					length: Math.sqrt(d.x * d.x + d.y * d.y),
				};
				derivs.push(SPAN({style: "color: " + lerp_colors[points.length - deriv.length]}, vector.length.toFixed(3)), ", ");
				ctx.save();
				const path = new Path2D;
				path.moveTo(curve_at_t.x, curve_at_t.y);
				const arrow = {
					x: curve_at_t.x + d.x / factor / factor / 2, //Divide through by a constant to make the lines fit nicely
					y: curve_at_t.y + d.y / factor / factor / 2, //I'm not sure why we're dividing by factor^2 here, but it seems to look better.
				};
				path.lineTo(arrow.x, arrow.y);
				const ARROW_ANGLE = 2.6; //Radians. If the primary vector is pointing on the X axis, the arrowhead lines point this many radians positive and negative.
				const ARROW_LENGTH = 12;
				for (let i = -1; i <= 1; i += 2) {
					path.lineTo(
						arrow.x + Math.cos(vector.angle + ARROW_ANGLE * i) * ARROW_LENGTH,
						arrow.y + Math.sin(vector.angle + ARROW_ANGLE * i) * ARROW_LENGTH,
					);
					path.moveTo(arrow.x, arrow.y);
				}
				ctx.strokeStyle = lerp_colors[points.length - deriv.length];
				ctx.stroke(path);
				ctx.restore();
			}
			derivs.push("and zero.");
			const k = (d1.x * d2.y - d1.y * d2.x) / (d1.x ** 2 + d2.y ** 2) ** 1.5;
			if (k) {
				const radius = 1 / k / 20;
				derivs.push(" Curve radius is ", radius.toFixed(3));
				if (state.shownearestcircle) {
					//Show the osculating circle at this point.
					//The center of it is 'radius' pixels away and is in the
					//direction orthogonal to the first derivative.
					const angle = Math.atan2(d1.y, d1.x) + Math.PI / 2;
					const circle_x = curve_at_t.x + Math.cos(angle) * radius;
					const circle_y = curve_at_t.y + Math.sin(angle) * radius;
					ctx.save();
					const path = new Path2D;
					path.arc(circle_x, circle_y, Math.abs(radius), 0, Math.PI * 2);
					//Mark the center
					path.moveTo(circle_x + 2, circle_y + 2);
					path.lineTo(circle_x - 2, circle_y - 2);
					path.moveTo(circle_x - 2, circle_y + 2);
					path.lineTo(circle_x + 2, circle_y - 2);
					ctx.stroke(path);
					ctx.restore();
				}
			}
			set_content("#derivatives", derivs);
		}
		draw_at(ctx, {type: "nearest", ...curve_at_t});
	}
	if (dragging) draw_at(ctx, dragging); //Anything being dragged gets drawn last, ensuring it is at the top of z-order.
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
		let best = 0.0, bestdist = -1;
		for (let t = 0; t <= 1; t += 1/RESOLUTION) {
			const p = interpolate(points, t);
			const dist = (p.x - e.offsetX) ** 2 + (p.y - e.offsetY) ** 2;
			if (bestdist < 0 || dist < bestdist) {bestdist = dist; best = t;}
		}
		highlight_t_value = best;
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
