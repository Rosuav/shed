import {lindt, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {DIV} = lindt; //autoimport

function render(grid, posr, posc) {
	const size = Math.max(Math.min(window.innerHeight / grid.length, window.innerWidth / grid[0].length, 100), 10);
	replace_content("#display", DIV(
		{class: "grid", "style":
			`grid-template-rows: repeat(${grid.length}, ${size}px);
			grid-template-columns: repeat(${grid[0].length}, ${size}px);`
		},
		grid.map((row, r) =>
			row.map((cell, c) => DIV({class: cell === "???" ? "wa wl wr wb" : cell},
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

let interval, start = +new Date;
function improve_maze(maze, walk, fast) {
	do { //In fast mode, keep going till the maze is fully generated, THEN render.
		if (!walk.length) {
			//Initialize our random walk with a cell at the top of the grid,
			//and make that the entrance.
			const entry = Math.floor(Math.random() * maze[0].length);
			walk.push([0, entry]);
			maze[0][entry] = "wl wr wb";
		}
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
			walk.pop();
			if (!walk.length) {
				//We've walked all the way back to the start, all is done! Pick an exit and mark it.
				const exit = Math.floor(Math.random() * maze[0].length);
				maze[maze.length - 1][exit] = maze[maze.length - 1][exit].split(" ").filter(w => w !== "wb").join(" ") + " exit";
				clearInterval(interval); interval = 0;
				//Mark the entrance as part of the path.
				maze[r][c] += " path";
				console.log("Finished after ", +new Date - start);
				break;
			}
		} else {
			const m = moves[Math.floor(Math.random() * moves.length)];
			let dr = r, dc = c, back;
			switch (m) {
				case "a": dr--; back = "b"; break;
				case "b": dr++; back = "a"; break;
				case "l": dc--; back = "r"; break;
				case "r": dc++; back = "l"; break;
			}
			//In this cell, remove the wall in the direction (above, below, left, right) we're going.
			maze[r][c] = maze[r][c].split(" ").filter(w => w !== "w" + m).join(" ");
			//And in the destination, remove the wall in the opposite direction. Note that the
			//destination will always have ALL its walls at this stage.
			maze[dr][dc] = ["wa", "wl", "wr", "wb"].filter(w => w !== "w" + back).join(" ");
			//Finally, move us to that position.
			walk.push([dr, dc]);
		}
	} while (fast);
	const w = walk[walk.length - 1];
	render(maze, w && w[0], w && w[1]);
}

function generate(fast) {
	clearInterval(interval); //Cancel any currently-running generation
	const maze = initialize(DOM("#rows").value, DOM("#cols").value);
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
generate(1);
