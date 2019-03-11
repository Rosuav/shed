let width = 10, height = 10, mines = 10;
//game[row][col] is 0-8 for number of nearby mines, or 9 for mine here
let game = null;
const board = document.getElementById("board");

function set_content(elem, children) {
	while (elem.lastChild) elem.removeChild(elem.lastChild);
	if (!Array.isArray(children)) children = [children];
	for (let child of children) {
		if (child === "") continue;
		if (typeof child === "string") child = document.createTextNode(child);
		elem.appendChild(child);
	}
	return elem;
}
function build(tag, attributes, children) {
	const ret = document.createElement(tag);
	if (attributes) for (let attr in attributes) {
		if (attr.startsWith("data-")) //Simplistic - we don't transform "data-foo-bar" into "fooBar" per HTML.
			ret.dataset[attr.slice(5)] = attributes[attr];
		else ret[attr] = attributes[attr];
	}
	if (children) set_content(ret, children);
	return ret;
}

function dig(game, r, c) {
	const num = game[r][c];
	if (num > 9) return; //Already dug
	const btn = board.children[r].children[c].firstChild;
	if (num === 9) {
		//Boom!
		console.log("YOU DIED");
		//TODO: Mark game as over
		set_content(btn, "*"); //Not flat
		return;
	}
	game[r][c] += 10;
	if (!num)
	{
		btn.classList.add("flat"); //Don't show the actual zero
		for (let dr = -1; dr <= 1; ++dr) for (let dc = -1; dc <= 1; ++dc) {
			if (r+dr < 0 || r+dr >= height || c+dc < 0 || c+dc >= width) continue;
			dig(game, r+dr, c+dc);
		}
		return;
	}
	set_content(btn, "" + num); btn.classList.add("flat");
}

function clicked(ev) {
	const btn = ev.currentTarget;
	dig(game, +btn.dataset.r, +btn.dataset.c);
	btn.blur();
}

function generate_game() {
	const game = [];
	if (mines * 10 > height * width) {
		console.error("Too many mines (TODO: handle this better)");
		return;
	}
	for (let r = 0; r < height; ++r) {
		const row = [];
		for (let c = 0; c < width; ++c) row.push(0);
		game.push(row); //game.push([0] * width), please?? awww
	}
	//TODO optionally: Use a seedable PRNG with consistent algorithm, and be
	//able to save pre-generated grids by recording their seeds. Or just save
	//the mine grid, encoded compactly (eg saving just the mine locations).
	for (let m = 0; m < mines; ++m) {
		const r = Math.floor(Math.random() * height);
		const c = Math.floor(Math.random() * width);
		if (game[r][c] === 9) {--m; continue;} //Should be fine to just reroll - you can't have a near-full grid anyway
		if (r < 2 && c < 2) {--m; continue;} //Guarantee empty top-left cell as starter
		game[r][c] = 9;
		for (let dr = -1; dr <= 1; ++dr) for (let dc = -1; dc <= 1; ++dc) {
			if (r+dr < 0 || r+dr >= height || c+dc < 0 || c+dc >= width) continue;
			if (game[r+dr][c+dc] !== 9) game[r+dr][c+dc]++;
		}
	}
	return game;
}

function get_unknowns(game, r, c) {
	//Helper for try_solve - get an array of the unknown cells around a cell
	//Returns [n, [r,c], [r,c], [r,c]] with any number of row/col pairs
	if (game[r][c] < 10) return null; //Shouldn't happen
	const ret = [game[r][c]];
	for (let dr = -1; dr <= 1; ++dr) for (let dc = -1; dc <= 1; ++dc) {
		if (r+dr < 0 || r+dr >= height || c+dc < 0 || c+dc >= width) continue;
		const cell = game[r+dr][c+dc];
		if (cell < 10) ret.push([r+dr, c+dc]);
		if (cell === 19) ret[0]--;
	}
	return ret;
}

//Try to solve the game. Duh :)
//Algorithm is pretty simple. Build an array of regions
function try_solve(game) {
	//First, build up a list of trivial regions.
	for (let r = 0; r < height; ++r) for (let c = 0; c < width; ++c) {
		if (game[r][c] < 10) continue;
		const region = get_unknowns(game, r, c);
		if (region.length === 1) continue; //No unknowns
		if (region[0] === 0) {
			//There are no unflagged mines in this region!
			for (let i = 1; i < region.length; ++i)
				dig(game, region[i][0], region[i][1]);
		}
		if (region[1] === region.length - 1)
		{
			//There are as many unflagged mines as unknowns!
			//Unimplemented
			//for (let i = 1; i < region.length; ++i)
				//flag(game, region[i][0], region[i][1]);
		}
	}
	return true;
}

function new_game() {
	const table = [];
	for (let r = 0; r < height; ++r) {
		const tr = [];
		for (let c = 0; c < width; ++c)
			tr.push(build("td", 0, build("button", {"data-r": r, "data-c": c, onclick: clicked})));
		table.push(build("tr", 0, tr));
	}
	set_content(board, table);
	while (true) {
		const tryme = generate_game();
		if (!try_solve(tryme)) continue;
		game = tryme;
		break;
	}
	dig(game, 0, 0);
	console.log(game);
}

new_game();
