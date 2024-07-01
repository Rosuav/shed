import {lindt, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {DIV} = lindt; //autoimport

let rendered_maze;
let victory = false;
let pathendr = -1, pathendc = -1;
function render(grid, posr, posc) {
	rendered_maze = grid;
	const size = Math.floor(Math.max(Math.min(window.innerHeight / grid.length, window.innerWidth / grid[0].length, 100), 12));
	replace_content("#display", DIV(
		{class: "grid" + (victory ? " victory" : ""), "style":
			`grid-template-rows: repeat(${grid.length}, ${size}px);
			grid-template-columns: repeat(${grid[0].length}, ${size}px);`
		},
		grid.map((row, r) =>
			row.map((cell, c) => DIV(
				{class: cell === "???" ? "wa wl wr wb" : cell, "data-r": r, "data-c": c},
				posr === r && posc === c ? "*" : ""
			))
		)
	));
}

function initialize(rows, cols) {
	const grid = [];
	for (let r = 0; r < rows; ++r)
		grid.push(Array(+cols).fill("???"));
	return grid;
}

function adjacent(r, c, dir) {
	switch (dir) {
		case "a": return [r-1, c, "b"];
		case "b": return [r+1, c, "a"];
		case "l": return [r, c-1, "r"];
		case "r": return [r, c+1, "l"];
	}
}

let interval, start = +new Date;
function improve_maze(maze, walks, fast) {
	let preferred_exit = -1;
	if (!walks.length) {
		//Initialize our random walk with a cell at the top of the grid,
		//and make that the entrance.
		const entry = Math.floor(Math.random() * maze[0].length);
		walks.push([[0, entry]]);
		maze[0][entry] = "wl wr wb";
	}
	if (fast && walks[0].length > 1) {
		//If a predefined path has been given which gets us to the last row,
		//use the end of that path as the exit.
		const [r, c] = walks[0][walks[0].length - 1];
		if (r === maze.length - 1) preferred_exit = c;
	}
	do { //In fast mode, keep going till the maze is fully generated, THEN render.
		const walk = walks[walks.length - 1];
		const [r, c] = walk[walk.length - 1]; //Alright, now where were we?
		//And where can we go from there? Note that we assume that array[-1] and array[length]
		//are indexable and undefined (and make use of optional chaining for the rows). Thus
		//regions outside the maze are always considered to be non-targets, just as visited
		//cells are.
		const moves = [
			maze[r-1]?.[c] === "???" ? "a" : null,
			maze[r+1]?.[c] === "???" ? "b" : null,
			maze[r][c-1] === "???" ? "l" : null,
			maze[r][c+1] === "???" ? "r" : null,
		].filter(Boolean);
		//Okay, these are our valid moves. If there aren't any, back up one cell. Otherwise,
		//pick one at random and go that way, knocking down the corresponding wall.
		if (!moves.length) {
			//Pure backtracking is certainly an option. However, another option is to branch off.
			//This involves searching the entire current path, so it is more expensive; thus it is
			//done with probability decreasing as the path lengthens.
			/*if (Math.random() * walk.length < 0.5)*/ { //Hack: For now, ALWAYS do this search
				//Note that we only search the current walk, not previous ones.
				const starts = [];
				for (let pos of walk) {
					const [r, c] = pos;
					if (maze[r-1]?.[c] === "???"
						|| maze[r+1]?.[c] === "???"
						|| maze[r][c-1] === "???"
						|| maze[r][c+1] === "???")
							starts.push([r, c]);
				}
				if (starts.length) { //If not, fall back on backtracking. Chances are we're done anyway.
					const pos = starts[Math.floor(Math.random() * starts.length)];
					walks.push([pos]);
					continue;
				}
			}
			walk.pop();
			if (!walk.length) {
				//We've walked all the way back to the current branch point. Back to the end of the previous
				//branch, or the original path.
				walks.pop();
				if (walks.length) continue;
				//If we've walked all the way back to the start, all is done! Pick an exit and mark it.
				const exit = preferred_exit === -1 ? Math.floor(Math.random() * maze[0].length) : preferred_exit;
				maze[maze.length - 1][exit] = maze[maze.length - 1][exit].split(" ").filter(w => w !== "wb").join(" ") + " exit";
				clearInterval(interval); interval = 0;
				//Mark the entrance as part of the path.
				maze[r][c] += " path";
				pathendr = r; pathendc = c;
				console.log("Finished after ", +new Date - start);
				render(maze, r, c);
				return;
			}
		} else {
			const m = moves[Math.floor(Math.random() * moves.length)];
			const [dr, dc, back] = adjacent(r, c, m);
			//In this cell, remove the wall in the direction (above, below, left, right) we're going.
			maze[r][c] = maze[r][c].split(" ").filter(w => w !== "w" + m).join(" ");
			//And in the destination, remove the wall in the opposite direction. Note that the
			//destination will always have ALL its walls at this stage.
			maze[dr][dc] = ["wa", "wl", "wr", "wb"].filter(w => w !== "w" + back).join(" ");
			//Finally, move us to that position.
			walk.push([dr, dc]);
		}
	} while (fast);
	const walk = walks[walks.length - 1];
	const w = walk && walk[walk.length - 1];
	render(maze, w && w[0], w && w[1]);
}

function generate(fast) {
	clearInterval(interval); //Cancel any currently-running generation
	const maze = initialize(DOM("#rows").value, DOM("#cols").value);
	victory = false;
	start = +new Date;
	if (fast) return improve_maze(maze, [], 1);
	render(maze);
	//Attempt to generate the maze in 20 seconds, regardless of size.
	//Every cell has to be visited twice: first as we knock down a wall to get there, and then
	//a second time as we backtrack. Thus the time taken is exactly linear in number of cells
	//(or if you prefer, quadratic in the maze's dimension, assuming a squareish maze).
	let step = 20000 / maze.length / maze[0].length / 2;
	if (step > 250) step = 250; //But don't take forever on a 2x2.
	interval = setInterval(improve_maze, step, maze, []);
}
on("submit", "#generate", e => {e.preventDefault(); generate(1);});
on("click", "#watch", e => {e.preventDefault(); generate(0);});

let drawing = null;
on("click", "#draw", e => {
	e.preventDefault();
	clearInterval(interval); interval = 0;
	if (drawing && drawing.length) {
		//Generate a rendering token. This is a mess, would be a lot easier in other languages, but
		//it's more important for the token to be compact than for it to be parsed quickly.
		const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"; //Base64-ish alphabet

		//For small mazes (up to 64x64), we can store the dimensions and entry column in one 64-bit
		//value each. For larger mazes, we need two or even three such tokens. Four is the utter limit.
		const n = Math.max(rendered_maze.length, rendered_maze[0].length);
		const width = n <= 64 ? 1 : n <= 4096 ? 2 : n <= 262144 ? 3 : 4;
		//Note that we store the dimensions minus one, allowing a 64x64 maze to be stored in one byte
		//per value. However, it's not worth compacting further than that; we could pack three 4-bit
		//values into two tokens, allowing a 16x16 maze to be stored in one less byte. Big whoop.
		const arr = [rendered_maze.length - 1, rendered_maze[0].length - 1, drawing[0][1]];
		let token = "";
		arr.forEach(n => {
			for (let i = 1; i < width; ++i) {
				token += alphabet[n & 63];
				n >>= 6;
			}
			token += alphabet[n];
		});
		let lastrow = 0, lastcol = drawing[0][1];
		function direction(n) {
			const [r1, c1] = drawing[n - 1];
			const [r2, c2] = drawing[n];
			if (r2 > r1) return "00";
			if (r2 < r1) return "01";
			if (c2 > c1) return "10";
			if (c2 < c1) return "11";
		}
		//The bulk of the token consists of three directions per byte value. First, render the loose
		//0-2 at the start. (We've already rendered the first entry by storing the actual column.)
		const loose = (drawing.length - 1) % 3;
		if (loose) {
			let bits = "";
			for (let i = 1; i < loose + 1; ++i) bits += direction(i);
			token += alphabet[Number("0b" + bits)];
		}
		//Now the rest of it, which will be a multiple of three.
		for (let i = loose + 1; i < drawing.length; i += 3) {
			let bits = "";
			for (let j = i; j < i + 3; ++j) bits += direction(j);
			token += alphabet[Number("0b" + bits)];
		}
		//Right. That's all the directions (packed three to a byte). There are two last nuggets that
		//you'll need to decode that: the bit length for the initial three values, and the number of
		//directions in the first byte. We've capped the bit length at 4 and there can only be 0-2 in
		//the first byte, so we actually have a bunch of spare bits here if they're needed.
		token = alphabet[width * 4 + loose] + token;
		const url = new URL(location); url.hash = token;
		console.log(url.toString());
		start = +new Date;
		improve_maze(rendered_maze, [drawing], 1);
		drawing = null;
		return;
	}
	const maze = initialize(DOM("#rows").value, DOM("#cols").value);
	victory = false;
	render(maze);
	drawing = [];
});

function decode_token(token, debug) {
	//Inverse of the above token generation.
	if (token.length < 3) return;
	debug = debug ? "path " : "";
	const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
	const decode = {};
	for (let i = 0; i < alphabet.length; ++i) decode[alphabet[i]] = ("000000" + i.toString(2)).slice(-6);
	//The first character gives us our size width and the number of loose directions.
	const n = alphabet.indexOf(token[0]);
	const width = n >> 2, loose = n & 3;
	//We then combine 'width' byte values (six bits each) to get our three starting
	//values: rows, cols, and entry point.
	const arr = [];
	let tok = 1;
	for (let i = 0; i < 3; ++i) {
		let bits = "";
		for (let i = 0; i < width; ++i) bits = decode[token[tok++]] + bits;
		arr.push(Number("0b" + bits));
	}
	const maze = initialize(arr[0] + 1, arr[1] + 1);
	maze[0][arr[2]] = "wl wr wb " + debug;
	victory = false;
	const drawing = [[0, arr[2]]];
	let bits = loose ? decode[token[tok++]].slice(loose * -2) : "";
	while (tok < token.length) bits += decode[token[tok++]];
	while (bits !== "") {
		const cur = bits.slice(0, 2); bits = bits.slice(2);
		let [dr, dc] = drawing[drawing.length - 1];
		let r = dr, c = dc, dir, back;
		switch (cur) {
			case "00": r++; dir = "b"; back = "a"; break;
			case "01": r--; dir = "a"; back = "b"; break;
			case "10": c++; dir = "r"; back = "l"; break;
			case "11": c--; dir = "l"; back = "r"; break;
		}
		drawing.push([r, c]);
		maze[r][c] = ("wa wb wl wr " + debug).replace("w" + back + " ", "");
		maze[dr][dc] = maze[dr][dc].replace("w" + dir + " ", "");
	}
	start = +new Date;
	improve_maze(maze, [drawing], 1);
}
if (location.hash.length > 3) decode_token(location.hash.slice(1));
else generate(1);
window.draw = (url) => {
	DOM("#draw").hidden = false;
	if (url) document.body.appendChild(choc.STYLE(".grid {background: url(" + url + "); background-size: contain; background-repeat: no-repeat;"));
};
window.load = tok => decode_token(tok, 1);

let lastmark = null;
on("mousedown", ".grid div", e => mark(+e.match.dataset.r, +e.match.dataset.c));
on("mouseover", ".grid div", e => lastmark && mark(+e.match.dataset.r, +e.match.dataset.c));
document.onmouseup = e => lastmark = null; //Note, not using pointer capture since I want mouseovers. So if you drag outside the window, it may lose the next click.
function mark(r, c) {
	if (interval) return; //Wait till we're done building it!
	//Clicking a cell can have one of two (or three-ish) effects.
	//1. If that cell has three walls around it, fill it in, and mark a pseudo-wall at its one opening.
	//2. Alternatively, if that cell is adjacent to (and without a wall) the path, extend the path.
	//2a. Or if it's part of the path and has only one adjacent path section, un-path it.
	//3. Maze building ("drawing") mode: design the path. You may extend the path or retract it.
	if (drawing) {
		if (!drawing.length) {
			if (r) {console.warn("Start on the top row!"); return;}
			drawing.push([r, c]);
			rendered_maze[r][c] = "wl wr wb path";
			lastmark = "addpath";
			render(rendered_maze, r, c);
			return;
		}
		const dr = drawing[drawing.length - 1][0], dc = drawing[drawing.length - 1][1];
		if (dr === r && dc === c && drawing.length > 1) {
			//Unmark last spot
			if (lastmark !== null && lastmark !== "rempath") return; lastmark = "rempath";
			//There should be only one gap in this cell. Move that way, and close it.
			const cls = rendered_maze[r][c].split(" ");
			rendered_maze[r][c] = "???";
			drawing.pop();
			["a", "b", "l", "r"].forEach(dir => {
				if (cls.includes("w" + dir)) return;
				const [dr, dc, back] = adjacent(r, c, dir);
				rendered_maze[dr][dc] = "w" + back + " " + rendered_maze[dr][dc];
				render(rendered_maze, drawing[drawing.length - 1][0], drawing[drawing.length - 1][1]);
			});
			return;
		}
		//Expand the path. Current cell has to be untouched.
		if (rendered_maze[r][c] !== "???") return;
		if (lastmark !== null && lastmark !== "addpath") return; lastmark = "addpath";
		let dir, back;
		if (dr === r && Math.abs(dc - c) === 1) {
			//Left/right expansion
			dir = c > dc ? "r" : "l";
			back = c > dc ? "l" : "r";
		} else if (dc === c && Math.abs(dr - r) === 1) {
			//Up/down expansion
			dir = r > dr ? "b" : "a";
			back = r > dr ? "a" : "b";
		} else return;
		rendered_maze[r][c] = "wa wb wl wr path".replace("w" + back + " ", "");
		rendered_maze[dr][dc] = rendered_maze[dr][dc].replace("w" + dir + " ", "");
		drawing.push([r, c]);
		render(rendered_maze, r, c);
		return;
	}
	const cls = rendered_maze[r][c].split(" ");
	if (drawing && cls[0] === "???") {cls.pop(); cls.push("wa", "wb", "wl", "wr");}
	let missing, path;
	["a", "b", "l", "r"].forEach(dir => {
		if (cls.includes("w" + dir)) return;
		missing = missing ? "many" : dir;
		const [dr, dc, back] = adjacent(r, c, dir);
		const other = (rendered_maze[dr]?.[dc] || "").split(" ");
		if (other.includes("path")) path = path ? "many" : dir;
	});
	if (!drawing && missing && missing !== "many") {
		//1. Three walls? Fill it in.
		if (lastmark !== null && lastmark !== "dead") return; lastmark = "dead";
		rendered_maze[r][c] = cls.filter(c => c !== "path").join(" ") + " dead w" + missing;
		const [dr, dc, back] = adjacent(r, c, missing);
		if (cls.includes("path")) {pathendr = dr; pathendc = dc;}
		rendered_maze[dr][dc] += " w" + back;
	} else if (path && path !== "many") {
		//2. Next to the path?
		if (!cls.includes("path")) {
			if (victory) return; //After claiming victory, don't mark any new paths.
			const [dr, dc, back] = adjacent(r, c, path);
			if (lastmark !== null && lastmark !== "addpath") return; lastmark = "addpath";
			if (drawing) {
				//3. Draw the path.
				//Remove the wall between here and the path
				rendered_maze[r][c] = cls.filter(c => c !== "w" + path).join(" ");
				rendered_maze[dr][dc] = rendered_maze[dr][dc].split(" ").filter(c => c !== "w" + back).join(" ");
			} else if (dr !== pathendr || dc !== pathendc) return "not adjacent";
			rendered_maze[r][c] += " path";
			pathendr = r; pathendc = c;
			if (cls.includes("exit")) victory = true; //The path has reached the exit! GG!
		}
		//2a. Or, at the end of the path, and on it?
		else {
			if (cls.includes("exit")) return; //Don't unpathmark the exit square.
			if (lastmark !== null && lastmark !== "rempath") return; lastmark = "rempath";
			rendered_maze[r][c] = cls.filter(c => c !== "path").join(" ");
			const [dr, dc, back] = adjacent(r, c, path);
			if (drawing) {
				//Reinstate walls between these cells.
				rendered_maze[r][c] += " w" + path;
				rendered_maze[dr][dc] += " w" + back;
			} else {
				pathendr = dr; pathendc = dc;
			}
		}
	} else return "nope"; //No need to rerender
	render(rendered_maze, pathendr, pathendc);
}

function solve() {
	if (lastmark) return;
	lastmark = "dead";
	let repeat = 0;
	for (let r = 0; r < rendered_maze.length; ++r)
		for (let c = 0; c < rendered_maze[0].length; ++c)
			if (mark(r, c) !== "nope") repeat = 1;
	lastmark = null;
	if (repeat) setTimeout(solve, 1000);
}
window.solve = solve;

document.onkeydown = e => {
	if (interval) return;
	const dir = {
		ArrowUp: "a",
		ArrowDown: "b",
		ArrowLeft: "l",
		ArrowRight: "r",
	}[e.code];
	const pathend = rendered_maze[pathendr]?.[pathendc];
	if (!pathend || !dir) return;
	e.preventDefault();
	if (pathend.split(" ").includes("w" + dir)) {
		//If there's a wall that way, do nothing. Should we show error?
		//Flash the wall red maybe?
		return;
	}
	const [dr, dc, back] = adjacent(pathendr, pathendc, dir);
	const dest = rendered_maze[dr][dc];
	if (dest.split(" ").includes("path")) {
		//Backtracking. Remove the path marker from here.
		rendered_maze[pathendr][pathendc] = pathend.split(" ").filter(w => w !== "path").join(" ");
	} else {
		//Advancing. Have we solved it?
		rendered_maze[dr][dc] += " path";
		if (rendered_maze[dr][dc].split(" ").includes("exit")) victory = true;
	}
	pathendr = dr; pathendc = dc;
	render(rendered_maze, dr, dc);
};
