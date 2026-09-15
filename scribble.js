//Scribble on a canvas to save it as a form element
const canvas = document.querySelector("canvas");
const ctx = canvas.getContext("2d");
//Synchronize the canvas width to the element's size as governed by CSS
//This should ensure that one pixel is one pixel.
canvas.width = canvas.clientWidth;
canvas.height = canvas.clientHeight;

//Each line consists of 1 or more coordinate pairs, representing a start position and 0 or more segments.
const lines = [];
let drawing = null;
function repaint() {
	ctx.font = "12px 'Lexend', 'Noto Color Emoji', 'Noto Sans Symbols 2', sans-serif";
	ctx.clearRect(0, 0, canvas.width, canvas.height);
	ctx.beginPath();
	for (let line of lines) {
		//NOTE: Currently there's no differentiating the active line from others. Should it be in a different colour?
		ctx.moveTo(...line[0]);
		for (let point of line) ctx.lineTo(...point);
	}
	ctx.stroke();
}

canvas.addEventListener("pointerdown", e => {
	if (e.button) return; //Only left clicks
	e.preventDefault();
	e.target.setPointerCapture(e.pointerId);
	lines.push(drawing = [[e.offsetX, e.offsetY]]);
	repaint();
});

canvas.addEventListener("pointermove", e => {
	if (!drawing) return;
	const lastpos = drawing[drawing.length - 1];
	if (lastpos[0] === e.offsetX && lastpos[1] === e.offsetY) return; //Position hasn't moved enough to measure
	drawing.push([e.offsetX, e.offsetY]);
	repaint();
});

document.onkeydown = e => {
	if (e.key === "Escape" && drawing) {
		//Note that we don't release pointer capture until pointer up
		lines.pop();
		drawing = null;
		repaint();
	}
}

canvas.addEventListener("pointerup", e => {
	if (!drawing) return;
	e.target.releasePointerCapture(e.pointerId);
	drawing = null;
	repaint();
	document.querySelector("[name=scribble]").value = canvas.toDataURL();
});
