int main(int argc, array(string) argv)
{
	mapping args = Arg.parse(argv);
	int wrap = (int)args->wrap || 9999;
	array layers = ({});
	int x = 1, y = 1;
	foreach (args[Arg.REST], string file)
	{
		mapping img = Image.PNG._decode(Stdio.read_file(file) || Stdio.read_file(file + ".png"));
		layers += ({Image.Layer((["image": img->image, "alpha": img->alpha, "xoffset": x, "yoffset": y]))});
		x += img->image->xsize() + 2;
		if (x > wrap) {y += img->image->ysize() + 2; x = 1;}
	}
	Image.Layer l = Image.lay(layers);
	Image.Image result = Image.lay(({
		Image.Layer(l->xoffset() + l->xsize() + 1, l->yoffset() + l->ysize() + 1, Image.Color("white")),
		l,
	}))->image();
	Stdio.write_file(args->out || "grid.png", Image.PNG.encode(result));
	write("%O\n", result);
}
