//Steganographic demonstration
//Provide two images and a color depth for the hidden one
//Replaces the low bits of the base image with the (few) bits of the hidden

int main(int argc, array(string) argv)
{
	if (argc < 3) exit(1, "USAGE: pike %s baseimg hiddenimg [bits]\nToo many bits makes the result look wrong; too few makes the hidden image monochrome.\n");
	string baseimg = argv[1], hiddenimg = argv[2];
	int bits = argc>3 && (int)argv[3]; if (!bits) bits = 2;
	Image.Image base = Image.PNG.decode(Stdio.read_file(baseimg));
	int xsz = base->xsize(), ysz = base->ysize();
	if (bits < 0)
	{
		//Negative bits - decode.
		int shift = 8 + bits;
		for (int y=0; y<ysz; ++y) for (int x=0; x<xsz; ++x)
		{
			[int r, int g, int b] = base->getpixel(x, y);
			base->setpixel(x, y,
				r << shift,
				g << shift,
				b << shift,
			);
		}
		Stdio.write_file("Decoded.png", Image.PNG.encode(base));
		return 0;
	}
	Image.Image hide = Image.PNG.decode(Stdio.read_file(hiddenimg));
	if (hide->xsize() > xsz || hide->ysize() > ysz)
		exit(1, "Cannot hide a larger image in a smaller.\n");
	int mask = (255 >> bits) << bits; //Eight-bit mask with the low 'bits' bits cleared
	int shift = 8 - bits;
	xsz = min(xsz, hide->xsize());
	ysz = min(ysz, hide->ysize());
	for (int y=0; y<ysz; ++y) for (int x=0; x<xsz; ++x)
	{
		[int r1, int g1, int b1] = base->getpixel(x, y);
		[int r2, int g2, int b2] = hide->getpixel(x, y);
		base->setpixel(x, y,
			(r1&mask) | (r2 >> shift),
			(g1&mask) | (g2 >> shift),
			(b1&mask) | (b2 >> shift),
		);
	}
	Stdio.write_file("Stegan.png", Image.PNG.encode(base));
}
