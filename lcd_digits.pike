/* Find optimal character mappings for LCD panel large digits

Each character is drawn on a 3x3 grid, or more precisely, on a 17x26 matrix with dead cells:
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....

..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....

..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....
..... ..... .....

The gaps will always remain as gaps.

First step: Find an ideal way to display these, imagining that we could turn any pixel on or off as needed.
This will be done using a font from the system; the selection of font will require some contemplation.

Second step: Find ROM characters that give the best approximation to these. Will need to key in the full
5x8 matrices for each available ROM character. https://cdn-shop.adafruit.com/datasheets/WH2004A-CFH-JT%23.pdf
- Option 1: Allow bright dead pixels.
- Option 2: Disallow them, or at least strongly penalize them.

Third step: Design a maximum of eight RAM characters, for which we have full control of the 5x8 matrix.
Try to have the most improvement possible for each one.
*/

constant BLANK = ({0x00}) * 8;
constant CHARACTERS = ({
	({BLANK}) * 16, //00 - 0F - actually the RAM characters
	({BLANK}) * 16, //10 - 1F
	({ //20 - 2F
		BLANK,
		({0x04, 0x04, 0x04, 0x04, 0x00, 0x00, 0x04}),
		({0x0A, 0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00}),
		({0x0A, 0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x0A}),
		({0x04, 0x0F, 0x14, 0x0E, 0x05, 0x1E, 0x04}),
		({0x18, 0x19, 0x02, 0x04, 0x08, 0x13, 0x03}),
		({0x0C, 0x12, 0x14, 0x08, 0x14, 0x12, 0x0D}),
		({0x0C, 0x04, 0x08, 0x00, 0x00, 0x00, 0x00}),
		({0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02}),
		({0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08}),
		({0x00, 0x04, 0x15, 0x0E, 0x15, 0x04, 0x00}),
		({0x00, 0x04, 0x04, 0x1F, 0x04, 0x04, 0x00}),
		({0x00, 0x00, 0x00, 0x00, 0x0C, 0x04, 0x08}),
		({0x00, 0x00, 0x00, 0x1F, 0x00, 0x00, 0x00}),
		({0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C}),
		({0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x00}),
	}), ({ //30 - 3F
		({0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E}),
		({0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0D}),
		({0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F}),
		({0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E}),
		({0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02}),
		({0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E}),
		({0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E}),
		({0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08}),
		({0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E}),
		({0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C}),
		({0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x0C, 0x00}),
		({0x00, 0x0C, 0x0C, 0x00, 0x0C, 0x04, 0x08}),
		({0x02, 0x04, 0x08, 0x10, 0x08, 0x04, 0x02}),
		({0x00, 0x00, 0x1F, 0x00, 0x1F, 0x00, 0x00}),
		({0x08, 0x04, 0x02, 0x01, 0x02, 0x04, 0x08}),
		({0x0E, 0x11, 0x01, 0x02, 0x04, 0x00, 0x04}),
	}),
	//40-FF not yet implemented
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16, //0x80 - 0x8F
	({BLANK}) * 16, //0x90 - 0x9F
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16,
	({BLANK}) * 16,
});

int main() {
	Image.Fonts.set_font_dirs(({"/usr/share/fonts/truetype/dejavu"}));
	object font = Image.Fonts.open_font("DejaVu Sans", 32, 0);
	foreach ("0123456789" / "", string digit) {
		object img = font->write(digit)->autocrop();
		//Center the image in a 17x26 grid, or crop to the middle part if too big
		int xsz = 17, ysz = 26;
		int xofs = (img->xsize() - xsz) / 2, yofs = (img->ysize() - ysz) / 2;
		img = img->copy(xofs, yofs, xofs + xsz - 1, yofs + ysz - 1, 0, 0, 0);
		write("%O --> %d x %d\n", digit, img->xsize(), img->ysize());
		write("_" * img->xsize() + "\n");
		for (int r = 0; r < img->ysize(); ++r) {
			string line = "";
			for (int c = 0; c < img->xsize(); ++c) {
				//Note that we just look at the red component; it's assumed that green and blue are the same.
				int pixel = img->getpixel(c, r)[0];
				//For visuals, show an approximation of the darkness using a block-drawing character.
				string chr = " ";
				if (pixel >= 32) chr = "\u2591";
				if (pixel >= 96) chr = "\u2592";
				if (pixel >= 160) chr = "\u2593";
				if (pixel >= 224) chr = "\u2588";
				line += chr;
			}
			write("%s|\n", string_to_utf8(line));
		}
	}
}
