/* TODO

* Place and remove control points (changing the degree of the curve)
* On mouseover, show cursor indicating draggability
* Refine "nearest" with fewer than 256 initial samples, but then perturb around the last sample
* Different colours for different types of markers
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
	{kwd: "showminimum", lbl: "Show tightest curve", dflt: false},
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
let highlight_t_value = 0.0, minimum_curve_radius = 0.0;

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
const _pascals_triangle = [[1], [1]]
function _coefficients(degree) {
	if (degree <= 0) return []; //wut
	//assert intp(degree);
	if (!_pascals_triangle[degree]) {
		const prev = _coefficients(degree - 1); //Calculate (and cache) previous row as needed
		const ret = prev.map((c,i) => c + (prev[i-1]||0));
		_pascals_triangle[degree] = [...ret, 1];
	}
	return _pascals_triangle[degree];
}
function interpolate(points, t) {
	if (points.length <= 1) return points[0];
	const coef = _coefficients(points.length);
	//Calculate the binomial expansion of ((1-t) + t)^n as factors that apply to the points
	//I don't really have a good explanation of exactly what this is doing, if you feel like
	//contributing, please drop in a PR. Each term in the binomial expansion corresponds to
	//one of the points.
	const omt = 1 - t;
	let x = 0, y = 0;
	coef.forEach((c, i) => {
		//We raise (1-t) to the power of a decreasing value, and
		//t to the power of an increasing value, and that gives us
		//the next term in the series.
		x += points[i].x * c * (omt ** (coef.length - i - 1)) * (t ** i);
		y += points[i].y * c * (omt ** (coef.length - i - 1)) * (t ** i);
	});
	return {x, y};
}

function curve_derivative(points) {
	//The derivative of a curve is another curve with one degree lower,
	//whose points are all defined by the differences between other points.
	//This will tend to bring it close to zero, so it may not be viable to
	//draw the entire curve (unless we find a midpoint of some sort), but
	//we can certainly get a vector by taking some point on this curve.
	const deriv = [];
	for (let i = 1; i < points.length; ++i) {
		deriv.push({
			x: points[i].x - points[i - 1].x,
			y: points[i].y - points[i - 1].y,
		});
	}
	return deriv;
}

function signed_curvature(t, deriv1, deriv2) {
	//Calculate signed curvature, positive means curving right, negative means left
	const d1 = interpolate(deriv1, t);
	const d2 = interpolate(deriv2, t);
	//Since these interpolations aren't actually the derivatives (they need to be
	//scaled by 3 and 6 respectively), the final k-value needs to be adjusted to
	//compensate. The net effect is a two-thirds scaling factor.
	return (d1.x * d2.y - d1.y * d2.x) / (d1.x ** 2 + d1.y ** 2) ** 1.5 * 2/3;
}

function curvature(t, deriv1, deriv2) {
	//Calculate curvature (often denoted Kappa), which we can depict
	//as 1/r for the osculating circle. If the curve derivatives are
	//precalculated, pass them, otherwise uses the elements list.
	if (!deriv1) deriv1 = curve_derivative(get_curve_points());
	if (deriv1.length < 2) return 0; //Lines don't have curvature.
	if (!deriv2) deriv2 = curve_derivative(deriv1);
	return Math.abs(signed_curvature(t, deriv1, deriv2));
}

const lerp_colors = ["#00000080", "#ee2222", "#11aa11", "#2222ee", "#ee22ee", "#aaaa11", "#11cccc"];
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
	if (method) {
		//Let the browser do the work for us.
		const coords = [];
		points.forEach(p => coords.push(p.x, p.y));
		path.moveTo(coords.shift(), coords.shift());
		path[method](...coords);
	}
	else if (points.length < 2) return; //C'mon, at least give me both endpoints!!
	else {
		//It's higher order than cubic, so we'll approximate it with RESOLUTION line segments.
		path.moveTo(points[0].x, points[0].y); //Start at the beginning...
		for (let i = 1; i <= RESOLUTION; ++i) { //Go on till you reach the end...
			const p = interpolate(points, i/RESOLUTION);
			path.lineTo(p.x, p.y);
		}
		//... then, uhh, stop? I guess?
	}
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
			let derivdesc = ["Derivatives at " + t.toFixed(3) + ": "];
			let derivs = []; //Mainly, track the first and second derivatives for the sake of osculating circle calculation
			while (deriv.length > 1) {
				factor *= (deriv.length - 1); //The derivative is multiplied by the curve's degree at each step
				deriv = curve_derivative(deriv);
				const d = interpolate(deriv, t);
				d.x *= factor; d.y *= factor; //Now it's the actual derivative at t.
				derivs.push(d);
				const vector = {
					angle: Math.atan2(d.y, d.x),
					length: Math.sqrt(d.x * d.x + d.y * d.y),
				};
				derivdesc.push(SPAN({style: "color: " + lerp_colors[points.length - deriv.length]}, vector.length.toFixed(3)), ", ");
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
			derivdesc.push("and zero.");
			const d1 = derivs[0], d2 = derivs[1];
			const k = (d1.x * d2.y - d1.y * d2.x) / (d1.x ** 2 + d1.y ** 2) ** 1.5;
			if (k) {
				const radius = 1 / k;
				derivdesc.push(" Curve radius is ", SPAN({style: "color: rebeccapurple"}, radius.toFixed(3)));
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
					//Since curvature is denoted with Kappa, it seems right to use
					//purple. But not Twitch Purple. Let's use Rebecca Purple.
					ctx.strokeStyle = "rebeccapurple";
					ctx.stroke(path);
					ctx.restore();
				}
			}
			set_content("#derivatives", derivdesc);
		}
		draw_at(ctx, {type: "nearest", ...curve_at_t});
	}
	set_content("#minimum_curve_radius", [
		"Minimum curve radius for this curve is: ",
		SPAN({style: "display: none"}, "at t=" + minimum_curve_radius + " "), //Currently not shown
		SPAN("" + (1/curvature(minimum_curve_radius)).toFixed(3)),
	]);
	if (state.showminimum && points.length > 2) {
		const deriv1 = curve_derivative(points);
		const deriv2 = curve_derivative(deriv1);
		const radius = 1 / signed_curvature(minimum_curve_radius, deriv1, deriv2);
		const curve_at_t = interpolate(points, minimum_curve_radius);
		const d1 = interpolate(deriv1, minimum_curve_radius);
		//Show the osculating circle at the point of minimum curve radius.
		const angle = Math.atan2(d1.y, d1.x) + Math.PI / 2; //A quarter turn away from the first derivative
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
		ctx.strokeStyle = "#880";
		ctx.stroke(path);
		ctx.restore();
	}
	if (dragging) draw_at(ctx, dragging); //Anything being dragged gets drawn last, ensuring it is at the top of z-order.
}

function calc_min_curve_radius() {
	//Calculate the minimum curve radius and the t-value at which that occurs.
	//Note that, since this uses sampling rather than truly solving the equation,
	//it may not give the precise minimum in situations where there are two local
	//minima that are comparably close. It'll show the other one though.
	const deriv1 = curve_derivative(get_curve_points());
	if (deriv1.length < 2) {minimum_curve_radius = 0.0; return;} //Lines aren't curved.
	const deriv2 = curve_derivative(deriv1);
	let best = 0.0, curve = 0;
	for (let t = 0; t <= 1; t += 1/RESOLUTION) {
		const k = curvature(t, deriv1, deriv2);
		if (k > curve) {curve = k; best = t;}
	}
	//TODO: Binary search +/- RESOLUTION from this t-value to see if we can refine the
	//calculation a bit. We could then lower the resolution a bit.
	minimum_curve_radius = best;
}
calc_min_curve_radius();
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
		calc_min_curve_radius();
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
	calc_min_curve_radius();
	repaint();
});
