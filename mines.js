let width = 10, height = 10, mines = 10;
//game[row][col] is 0-8 for number of nearby mines, or 9 for mine here
const game = [];
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

function dig(r, c) {
	const num = game[r][c];
	if (num === 9) {
		//Boom!
		console.log("YOU DIED");
		//TODO: Mark game as over
		set_content(board.children[r].children[c].firstChild, "*");
		return;
	}
	set_content(board.children[r].children[c].firstChild, "" + num);
	//TODO: If num === 0, dig all adjacent cells
}

function clicked(ev) {
	const btn = ev.currentTarget;
	dig(+btn.dataset.r, +btn.dataset.c);
}

function new_game() {
	const table = [];
	for (let r = 0; r < height; ++r) {
		const row = [], tr = [];
		for (let c = 0; c < width; ++c) {
			row.push(0);
			tr.push(build("td", 0, build("button", {"data-r": r, "data-c": c, onclick: clicked})));
		}
		game.push(row);
		table.push(build("tr", 0, tr));
	}
	set_content(board, table);
	if (mines * 10 > height * width) {
		console.error("Too many mines (TODO: handle this better)");
		return;
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
	dig(0, 0);
	console.log(game);
}

new_game();
