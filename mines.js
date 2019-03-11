let width = 10, height = 10, mines = 10;
//game[row][col] is 0-8 for number of nearby mines, or 9 for mine here
const game = [];

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

function clicked(ev) {
	const btn = ev.currentTarget;
	console.log("Clicked", btn.dataset.r, btn.dataset.c);
}

function new_game() {
	const board = document.getElementById("board");
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
		if (game[r][c]) {--m; continue;} //Should be fine to just reroll - you can't have a near-full grid anyway
		game[r][c] = 9;
	}
	console.log(game);
}

new_game();
