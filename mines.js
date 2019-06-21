//game[row][col] is 0-8 for number of nearby mines, or 9 for mine here
let game = null;
const board = document.getElementById("board");
let mines_left = 0;
let gamestate = "not-started"; //Or playing, dead, won
let starttime = new Date;
const game_status = document.getElementById("game_status");
let hint_cells = [], hint_mines = 0;

import build, {set_content} from "https://rosuav.github.io/shed/chocfactory.js";

function die(game, r, c, board) {
	if (!board) throw new Error("You died"); //Should never happen on simulation - it's a fault in the autosolver
	const btn = board.children[r].children[c].firstChild;
	if (game[r][c] === 9) set_content(btn, "*"); //Not flat
	else set_content(btn, "" + game[r][c]);
	btn.classList.add("death");
	gamestate = "dead";
	set_content(game_status, "YOU DIED"); //Mr Reynolds
	//Reveal the rest of the board, but don't flatten anything
	for (let rr = 0; rr < game.length; ++rr) for (let cc = 0; cc < game[rr].length; ++cc)
	{
		if (rr === r && cc === c) continue; //Ignore the cell we just died at
		if (game[rr][cc] > 9) continue; //Ignore previously-marked cells
		const b = board.children[rr].children[cc].firstChild;
		if (game[rr][cc] === 9) set_content(b, "?");
		else if (game[rr][cc]) set_content(b, "" + game[rr][cc]);
	}
}

function win() {
	//Never called as part of simulation
	gamestate = "won";
	set_content(game_status, "Victory in " + (new Date - starttime)/1000 + " seconds!");
	for (let rr = 0; rr < game.length; ++rr) for (let cc = 0; cc < game[rr].length; ++cc)
	{
		if (game[rr][cc] > 9) continue; //Ignore previously-marked cells
		const b = board.children[rr].children[cc].firstChild;
		if (game[rr][cc] === 9) {set_content(b, "*"); continue;}
		if (game[rr][cc]) set_content(b, "" + game[rr][cc]);
		b.classList.add("flat");
	}
}

//Returns an array of the cells dug. This can be empty (if the cell was not
//unknown), just the given cell (if it was unknown and had mines nearby), or
//a full array of many cells (if that cell had been empty).
function dig(game, r, c, board, dug=[]) {
	const num = game[r][c];
	if (num > 9) return dug; //Already dug/flagged
	if (num === 9) {
		//Boom!
		die(game, r, c, board);
		return dug;
	}
	game[r][c] += 10;
	dug.push([r, c]);
	const btn = board && board.children[r].children[c].firstChild;
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
	if (num > 9) return false; //Already dug/flagged
	const btn = board && board.children[r].children[c].firstChild;
	if (num === 9) {
		if (btn) set_content(btn, "*"); //Not flat
		game[r][c] = 19;
		return true;
	}
	//Boom! Flagged a non-mine.
	die(game, r, c, board);
	return false;
}

function startgame() {
	starttime = new Date;
	gamestate = "playing";
}

function update_hint_text()
{
	let hint_text;
	switch (hint_cells.length) {
		case 0: hint_text = ""; break;
		case 1:
			if (hint_mines) hint_text = "This cell is a mine.";
			else hint_text = "This cell is clear.";
			break;
		default:
			if (hint_mines === hint_cells.length) hint_text = "These cells are mines.";
			else if (!hint_mines) hint_text = "These cells are clear.";
			else hint_text = "The red cells are mines, the blue ones are clear."; //Not possible as of 20190326 but future expansion could create it
	}
	set_content(document.getElementById("hint_text"), hint_text);
}

function highlight(r, c) {
	const cell = game[r][c];
	if (cell < 10) return false;
	console.log("Cell already shown");
	const region = get_unknowns(game, r, c);
	console.log(region);
	let highlight_text;
	//Very similar to hint_text above, but has more grammatical possibilities.
	switch (region.length) { //Note that region.length is one greater than the number of unknowns.
		case 1: highlight_text = "There are no unknown cells near that one."; break;
		case 2:
			if (region[0]) highlight_text = "This cell is a mine.";
			else highlight_text = "This cell is clear.";
			break;
		case 3:
			if (region[0] === 2) highlight_text = "These cells are both mines.";
			else if (!region[0]) highlight_text = "These cells are both clear.";
			else highlight_text = "One of these two cells is a mine.";
			break;
		default:
			if (region[0] === region.length - 1) highlight_text = "These cells are all mines.";
			else if (!region[0]) highlight_text = "These cells are all clear.";
			else if (region[0] === 1) highlight_text = "One of these " + (region.length - 1) + " cells is a mine.";
			else highlight_text = region[0] + " of these " + (region.length - 1) + " cells are mines.";
			break;
	}
	set_content(document.getElementById("highlight_text"), highlight_text);
	document.querySelectorAll("button").forEach(btn => btn.classList.remove("region"));
	for (let i = 1; i < region.length; ++i) {
		const btn = board.children[region[i][0]].children[region[i][1]].firstChild;
		btn.classList.add("region");
	}
	return true;
}

board.onclick = ev => {
	const btn = ev.target; if (btn.tagName != "BUTTON") return;
	if (gamestate === "not-started") startgame();
	else if (gamestate !== "playing") return;
	if (highlight(+btn.dataset.r, +btn.dataset.c)) {btn.blur(); return;}
	for (let dug of dig(game, +btn.dataset.r, +btn.dataset.c, board))
	{
		//TODO: Do set operations, not stupid array removal
		const idx = hint_cells.indexOf(dug[0] + "," + dug[1]);
		const btn = board.children[dug[0]].children[dug[1]].firstChild;
		btn.classList.remove("hint_clear", "region");
		if (idx !== -1) {
			hint_cells.splice(idx, 1);
			update_hint_text();
		}
	}
	btn.blur();
};

board.oncontextmenu = ev => {
	ev.preventDefault();
	const btn = ev.target; if (btn.tagName != "BUTTON") return;
	if (gamestate === "not-started") startgame();
	else if (gamestate !== "playing") return;
	if (highlight(+btn.dataset.r, +btn.dataset.c)) {btn.blur(); return;}
	if (flag(game, +btn.dataset.r, +btn.dataset.c, board)) {
		--mines_left;
		set_content(game_status, mines_left + " mines left.");
		btn.classList.remove("hint_mine", "region");
		const idx = hint_cells.indexOf(btn.dataset.r + "," + btn.dataset.c);
		if (idx !== -1) {
			hint_cells.splice(idx, 1);
			--hint_mines;
			update_hint_text();
		}
		if (!mines_left) win();
	}
};

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
//If single_step is true, will search until a single hint is found, then THROWS
//a pair of arrays: known clear cells, known mines. Yes. It throws. Deal with it.
function try_solve(game, totmines, single_step=false) {
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
			if (single_step) throw [region.slice(1), []];
			for (let i = 1; i < region.length; ++i)
				//Dig everything. Whatever we dug, add as a region.
				for (let dug of dig(game, region[i][0], region[i][1]))
					base_region(dug[0], dug[1]);
		}
		else if (region[0] === region.length - 1)
		{
			//There are as many unflagged mines as unknowns!
			DEBUG("All mines");
			if (single_step) throw [[], region.slice(1)];
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

document.getElementById("hint").onclick = ev => {
	ev.preventDefault();
	if (hint_cells.length || gamestate !== "playing") return;
	try {
		if (try_solve(game, mines_left, true)) console.warn("Game's already over?");
		else console.warn("Game's unsolvable?"); //Neither of these should happen
	}
	catch (hint) {
		//TODO: If 'hint' isn't an array, reraise, it's a failure of some sort
		for (let i = 0; i < 2; ++i) for (let cell of hint[i])
		{
			hint_cells.push(cell[0] + "," + cell[1]);
			hint_mines += i;
			const btn = board.children[cell[0]].children[cell[1]].firstChild;
			btn.classList.add(["hint_clear", "hint_mine"][i]);
		}
		update_hint_text();
	}
};

function new_game(height, width, mines) {
	let tries = 0;
	game = null; gamestate = "not-started";
	while (true) {
		const tryme = generate_game(height, width, mines);
		if (++tries >= 10000) break;
		dig(tryme, 0, 0);
		if (!try_solve(tryme, mines)) continue;
		game = tryme;
		break;
	}
	if (!game) {console.log("Couldn't find a game in " + tries + " tries."); return;}
	else if (tries === 1) console.log("Got a game first try");
	else console.log("Got a game in " + tries + " tries.");
	//Flip all the cells face-down again (simpler than copying the array)
	for (let row of game) for (let i = 0; i < row.length; ++i) if (row[i] > 9) row[i] -= 10;
	mines_left = mines; set_content(game_status, mines_left + " mines to find.");
	dig(game, 0, 0);
	console.log(game);
	const table = [];
	for (let r = 0; r < game.length; ++r) {
		const tr = [];
		for (let c = 0; c < game[0].length; ++c)
		{
			let content = "\xA0"; //Having a non-breaking space on the buttons makes the alignment tidier than having them empty does. :(
			const attr = {"data-r": r, "data-c": c};
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

document.querySelectorAll(".newgame").forEach(btn => btn.onclick = ev => {
	ev.preventDefault();
	const btn = ev.currentTarget;
	const h = +btn.dataset.height, w = +btn.dataset.width, m = +btn.dataset.mines;
	if (!h || !w || !m) return;
	new_game(h, w, m);
});

new_game(10, 10, 10);
