const canvas = document.querySelector("canvas");
const ctx = canvas.getContext("2d");

function repaint() {
	ctx.font = "12px 'Lexend', 'Noto Color Emoji', 'Noto Sans Symbols 2', sans-serif";
	ctx.clearRect(0, 0, canvas.width, canvas.height);
}

canvas.addEventListener("pointerdown", e => {
	if (e.button) return; //Only left clicks
	e.preventDefault();
	e.target.setPointerCapture(e.pointerId);
});

canvas.addEventListener("pointermove", e => {
});

document.onkeydown = e => {
	if (e.key === "Escape") {
		//Note that we don't release pointer capture until pointer up
		repaint();
	}
}

canvas.addEventListener("pointerup", e => {
	//if (!dragging) return;
	e.target.releasePointerCapture(e.pointerId);
});
