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

//Returns an array of the cells dug. This can be empty (if the cell was not
//unknown), just the given cell (if it was unknown and had mines nearby), or
//a full array of many cells (if that cell had been empty).
function dig(game, r, c, board, dug=[]) {
	const num = game[r][c];
	if (num > 9) return dug; //Already dug/flagged
	const btn = board && board.children[r].children[c].firstChild;
	if (num === 9) {
		//Boom!
		if (!board) throw new Error("You died"); //Should never happen on simulation - it's a fault in the autosolver
		console.log("YOU DIED");
		//TODO: Mark game as over
		set_content(btn, "*"); //Not flat
		return dug;
	}
	game[r][c] += 10;
	dug.push([r, c]);
	if (!num)
	{
		if (btn) btn.classList.add("flat"); //Don't show the actual zero
		for (let dr = -1; dr <= 1; ++dr) for (let dc = -1; dc <= 1; ++dc) {
			if (r+dr < 0 || r+dr >= game.length || c+dc < 0 || c+dc >= game[0].length) continue;
			dig(game, r+dr, c+dc, board, dug);
		}
		return dug;
	}
	if (btn) {set_content(btn, "" + num); btn.classList.add("flat");}
	return dug;
}

function flag(game, r, c, board) {
	const num = game[r][c];
	if (num > 9) return; //Already dug/flagged
	const btn = board && board.children[r].children[c].firstChild;
	if (num === 9) {
		if (btn) set_content(btn, "*"); //Not flat
		game[r][c] = 19;
		return;
	}
	//Boom! Flagged a non-mine.
	if (!board) throw new Error("You died"); //As above, shouldn't happen in simulation.
	console.log("YOU DIED");
	//TODO: Mark game as over
	set_content(btn, "" + num);
}

function clicked(ev) {
	const btn = ev.currentTarget;
	dig(game, +btn.dataset.r, +btn.dataset.c, board);
	btn.blur();
}

function blipped(ev) {
	ev.preventDefault();
	const btn = ev.currentTarget;
	flag(game, +btn.dataset.r, +btn.dataset.c, board);
}

function generate_game(height, width, mines) {
	const game = [];
	if (mines * 4 > height * width) {
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
		const r = Math.floor(Math.random() * game.length);
		const c = Math.floor(Math.random() * game[0].length);
		if (game[r][c] === 9) {--m; continue;} //Should be fine to just reroll - you can't have a near-full grid anyway
		if (r < 2 && c < 2) {--m; continue;} //Guarantee empty top-left cell as starter
		game[r][c] = 9;
		for (let dr = -1; dr <= 1; ++dr) for (let dc = -1; dc <= 1; ++dc) {
			if (r+dr < 0 || r+dr >= game.length || c+dc < 0 || c+dc >= game[0].length) continue;
			if (game[r+dr][c+dc] !== 9) game[r+dr][c+dc]++;
		}
	}
	return game;
}

function get_unknowns(game, r, c) {
	//Helper for try_solve - get an array of the unknown cells around a cell
	//Returns [n, [r,c], [r,c], [r,c]] with any number of row/col pairs
	if (game[r][c] < 10) return null; //Shouldn't happen
	const ret = [game[r][c] - 10];
	for (let dr = -1; dr <= 1; ++dr) for (let dc = -1; dc <= 1; ++dc) {
		if (r+dr < 0 || r+dr >= game.length || c+dc < 0 || c+dc >= game[0].length) continue;
		const cell = game[r+dr][c+dc];
		if (cell < 10) ret.push([r+dr, c+dc]);
		if (cell === 19) ret[0]--;
	}
	return ret;
}

//const DEBUG = console.log;
const DEBUG = () => 0;

//Try to solve the game. Duh :)
//Algorithm is pretty simple. Build an array of regions, where a "region" is some
//group of unknown cells with a known number of mines among them. The initial set
//of regions comes from the dug cells - if the cell says "2" and it has three
//unknown cells adjacent to it and no flagged mines, we have a "two mines in three
//cells" region. Any region with no mines in it, or as many mines as cells, can be
//dug/flagged immediately. Then, proceed to subtract regions from regions: if one
//region is a strict subset of another, the difference is itself a region. So if
//two of the cells are also in a region of one mine, then the one cell NOT in the
//smaller region must have a mine in it. (The algorithm is simpler than it sounds.)
//Note that the *entire board* also counts as a region. This ensures that the
//search will correctly recognize iced-in sections as unsolveable, unless there are
//exactly the right number of mines for the section.
//TODO: Also handle overlaps between regions. Not every overlap yields new regions;
//it's only of value if you can divide the space into three parts: [ x ( x+y ] y )
//where the number of mines in regions X and Y are such that the *only* number of
//mines that can be in the x+y overlap would leave the x-only as all mines and the
//y-only as all clear. Look for these only if it seems that the game is unsolvable.
function try_solve(game, totmines) {
	//First, build up a list of trivial regions.
	//One big region for the whole board:
	let regions = [[totmines]];
	for (let r = 0; r < game.length; ++r) for (let c = 0; c < game[0].length; ++c)
		if (game[r][c] === 19) regions[0][0]--;
		else if (game[r][c] < 10) regions[0].push([r, c]);
	//And then a region for every cell we know about.
	const base_region = (r, c) => {
		if (game[r][c] < 10 || game[r][c] === 19) return;
		const region = get_unknowns(game, r, c);
		if (region.length === 1) return; //No unknowns
		DEBUG(r, c, region);
		new_region(region);
	};
	const new_region = region => {
		if (region[0] === 0) {
			//There are no unflagged mines in this region!
			DEBUG("All clear");
			for (let i = 1; i < region.length; ++i)
				//Dig everything. Whatever we dug, add as a region.
				for (let dug of dig(game, region[i][0], region[i][1]))
					base_region(dug[0], dug[1]);
		}
		else if (region[0] === region.length - 1)
		{
			//There are as many unflagged mines as unknowns!
			DEBUG("All mines");
			for (let i = 1; i < region.length; ++i)
				flag(game, region[i][0], region[i][1]);
		}
		else regions.push(region);
	};
	for (let r = 0; r < game.length; ++r) for (let c = 0; c < game[0].length; ++c) base_region(r, c);
	DEBUG("Searching for subsets.");
	for (let reg of regions)
	{
		let desc = reg[0] + " mines in";
		for (let i = 1; i < reg.length; ++i) desc += " " + reg[i][0] + "," + reg[i][1];
		DEBUG(desc);
	}
	//Next, try to find regions that are strict subsets of other regions.
	let found = true;
	while (found) {
		found = false;
		for (let r1 of regions) {
			//TODO: Don't do this quadratically. Recognize which MIGHT be subsets.
			//Transform the region into something we can more easily look up (with stringified keys)
			const reg = {}; for (let i = 1; i < r1.length; ++i) reg[r1[i].join("-")] = 1;
			DEBUG(reg);
			for (let r2 of regions) {
				//See if r2 is a strict subset of r1
				//In Python, I would represent coordinates as (r,c) tuples, and put them
				//into a set, which I could then directly compare, difference, etc. Sigh.
				if (!r2.length || r2.length >= r1.length) continue;
				let i = 1;
				for (i = 1; i < r2.length; ++i) if (!reg[r2[i].join("-")]) break;
				if (i < r2.length) continue; //It's not a strict subset.
				DEBUG(r2);
				const reg2 = {}; for (let i = 1; i < r2.length; ++i) reg2[r2[i].join("-")] = 1;
				const newreg = r1.filter((r, i) => !i || !reg2[r.join("-")]);
				newreg[0] = r1[0] - r2[0];
				DEBUG("New region:", newreg);
				r1.splice(0); //Wipe the old region - we won't need it any more
				new_region(newreg);
				found = true;
			}
		}
		//Prune the region list. Any that have been wiped go; others get their
		//cell lists pruned to those still unknown.
		const scanme = regions; regions = [];
		DEBUG("Pruning:", scanme);
		for (let region of scanme) {
			if (!region.length) continue;
			for (let i = 1; i < region.length; ++i) {
				const cell = game[region[i][0]][region[i][1]];
				if (cell < 10) continue;
				region.splice(i, 1);
				if (cell === 19) region[0]--;
				found = true; //Changes were made.
			}
			if (region.length > 1) new_region(region); //Might end up being all-clear or all-mines, or a new actual region
		}
	}
	DEBUG("Final regions:", regions);
	return !regions.length;
}

function new_game() {
	let height = 10, width = 10, mines = 10;
	let tries = 0;
	while (true) {
		const tryme = generate_game(height, width, mines);
		++tries;
		//TODO: Copy tryme for the attempted solve
		dig(tryme, 0, 0);
		if (!try_solve(tryme, mines)) continue;
		game = tryme;
		break;
	}
	if (tries === 1) console.log("Got a game first try");
	else console.log("Got a game in " + tries + " tries.");
	dig(game, 0, 0);
	console.log(game);
	const table = [];
	for (let r = 0; r < game.length; ++r) {
		const tr = [];
		for (let c = 0; c < game[0].length; ++c)
		{
			let content = "";
			const attr = {"data-r": r, "data-c": c, onclick: clicked, oncontextmenu: blipped};
			if (game[r][c] === 19) content = "*";
			else if (game[r][c] > 10) {content = "" + (game[r][c] - 10); attr.className = "flat";}
			else if (game[r][c] === 10) attr.className = "flat";
			tr.push(build("td", 0, build("button", attr, content)));
		}
		table.push(build("tr", 0, tr));
	}
	set_content(board, table);
}
//Dump a game ready for testing
function dump_game() {console.log(JSON.stringify(game.map(row => row.map(cell => cell > 9 ? cell - 10 : cell))));}

new_game();
