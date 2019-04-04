constant TMPDIR = "/tmp/emotes";

//The Pike downloader doesn't like some of the HTTPS servers
//(possibly a cert issue). Easier to deal with it using curl.
string low_download(string url)
{
	//Use the internal downloader:
	//return Protocols.HTTP.get_url_data(url);
	//Use curl:
	return Process.run(({"curl", url}))->stdout;
	//Or use wget, or Python + requests, or whatever else.
}

//Download with a local cache. The cache is never expired.
string download(string url, string fn)
{
	fn = TMPDIR + "/" + replace(fn, "/", "SLASH");
	if (string data = Stdio.read_file(fn)) return data;
	string data = low_download(url);
	Stdio.write_file(fn, data);
	return data;
}

enum {CODE, IMG, CMP, AVG, CMPAVG, DENSITY, PERM, USAGE};
array parse_image(mapping em, int permanent)
{
	string data = download("https://static-cdn.jtvnw.net/emoticons/v1/" + em->id + "/2.0", em->code);
	Image.Image img = Image.PNG.decode(data);
	Image.Image alpha = Image.PNG.decode_alpha(data);
	//Put the image onto a neutral background using its alpha channel
	//~ img = Image.Image(img->xsize(), img->ysize(), 204, 204, 204)->paste_mask(img, alpha);
	//Or onto its average
	img = Image.Image(img->xsize(), img->ysize(), @(array(int))img->average())->paste_mask(img, alpha);
	object cmp = img->rgb_to_hsv(); //Or rgb_to_yuv(), or just same as img
	return ({ //Must match the enum above
		em->code,
		img,
		cmp,
		(array(int))img->average(),
		(array(int))cmp->average(),
		(int)alpha->average()[0],
		permanent,
		0, //Usage counter (mutable)
	});
}

//Figure out a relative score (lower is better) for an image
//1) Permanent is better than ephemeral
//2) Not yet used is WAY better than previously used
//3) Find the one closest to the target pixel colour
//~ constant W_R = 87, W_G = 127, W_B = 41; //Using RGB but scaling as per the grey() method
//~ constant W_R = 1, W_G = 1, W_B = 1; //Flat scaling
//~ constant W_R = 2, W_G = 4, W_B = 3; //Alternate but still simple scaling
//~ constant W_R = 1, W_G = 2, W_B = 1; //When using YUV (brightness in green, colour components in red and blue)
//~ constant W_R = 3, W_G = 1, W_B = 3; //YUV favouring the colour above the brightness
constant W_R = 5, W_G = 2, W_B = 2; //HSV favouring the hue

int score_image(array image, int r, int g, int b, int fast)
{
	int score = 0;
	Image.Image img = image[CMP];
	int w = img->xsize(), h = img->ysize();
	if (fast == 2) write("==> %O\n", image[CODE]);
	if (fast)
	{
		//Fast mode - pretend the image is a solid block of its average colour
		[int rr, int gg, int bb] = image[CMPAVG];
		score += W_R * (rr-r) ** 2 * w * h;
		score += W_G * (gg-g) ** 2 * w * h;
		score += W_B * (bb-b) ** 2 * w * h;
	}
	else
	{
		for (int x = 0; x < w; ++x) for (int y = 0; y < h; ++y)
		{
			[int rr, int gg, int bb] = img->getpixel(x, y);
			score += W_R * (rr-r) ** 2;
			score += W_G * (gg-g) ** 2;
			score += W_B * (bb-b) ** 2;
		}
	}
	if (!image[PERM]) score += w * h * 500000; //That's about half the maximum distance for each colour angle
	score += image[USAGE] * w * h * 1000000;
	//~ score += (256-image[DENSITY]) * w * h * 100000;
	if (fast == 2)
	{
		if (!score) score = 1;
		[int rr, int gg, int bb] = image[CMPAVG];
		int red = W_R * (rr-r) ** 2 * w * h;
		int grn = W_G * (gg-g) ** 2 * w * h;
		int blu = W_B * (bb-b) ** 2 * w * h;
		int perm = image[PERM] ? 0 : w * h * 5000000;
		int usage = image[USAGE] * w * h * 10000000;
		write("R:  87 * (%3d-%3d) ** 2 * %d * %d = %d => %d\n", rr, r, w, h, red, red * 100 / score);
		write("G: 127 * (%3d-%3d) ** 2 * %d * %d = %d => %d\n", gg, g, w, h, grn, grn * 100 / score);
		write("B:  41 * (%3d-%3d) ** 2 * %d * %d = %d => %d\n", bb, b, w, h, blu, blu * 100 / score);
		write("Perm:  %d => %d\n", perm, perm * 100 / score);
		write("Usage: %d => %d\n", usage, usage * 100 / score);
		write("Total: %d => %d\n", score, (red+grn+blu+perm+usage) * 100 / score);
	}
	return score;
}

int main(int argc, array(string) argv)
{
	if (argc < 2) exit(1, "USAGE: pike %s emotename\n", argv[0]);
	Stdio.mkdirhier(TMPDIR, 0700);
	write("Fetching... ");
	mapping emotes = Standards.JSON.decode(low_download("https://sikorsky.rosuav.com/emotes?format=json"));
	//write("\rFetching %d emotes... ", sizeof(emotes->ephemeral) + sizeof(emotes->permanent)); //need to drill another level in to get a counter
	array images = ({ });
	//~ foreach (emotes->ephemeral; string channel; array em) images += parse_image(em[*], 0);
	foreach (emotes->permanent; string channel; array em) images += parse_image(em[*], 1);
	//~ images = parse_image(emotes->permanent->rosuav[*], 1);
	//~ images += parse_image(emotes->permanent->stephenangelico[*], 1);
	//Okay. Now we have a ton of images.
	//Pick the best based on a score (see score_image).
	//To do this perfectly, we would have to look at every image and every pixel in that
	//image, and find the distance-squared to the three dimensional location of the colour
	//that we want. But simplifying it can be done by taking the average colour of each
	//image, and then ranking the images based on that.
	write("%d loaded.\n", sizeof(images));
	array base;
	foreach (images, array im) if (im[CODE] == argv[1]) {base = im; break;}
	if (!base) exit(1, "Emote %O not found, or unavailable\n", argv[1]);
	Image.Image base_img = base[IMG];
	Image.Image base_cmp = base[CMP];
	int w = base_img->xsize(), h = base_img->ysize();
	Image.Image target = Image.Image(w * w, h * h, 204, 204, 204);

	//~ [int r, int g, int b] = base_img->getpixel(w/2, h/2);
	//~ [int r, int g, int b] = (array(int))base_img->average();
	//~ array(int) scores = score_image(images[*], r, g, b, 2);
	//~ return 1;

	for (int x = 0; x < w; ++x) for (int y = 0; y < h; ++y)
	{
		array pixel = base_img->getpixel(x, y);
		array(int) scores = score_image(images[*], @pixel, 1); //Caution: can segfault some versions of Pike
		//[int r, int g, int b] = base_cmp->getpixel(x, y);
		//array(int) scores = score_image(images[*], r, g, b, 1); //But avoiding @ is safe on all versions.
		array imgs = images + ({ });
		sort(scores, imgs);
		//~ write("%{%d %}|%{ %d%}\n", scores[..2], scores[<2..]);
		//Having scored every image using the fast algorithm, we now refine it
		//by scoring the best handful using the more accurate algorithm.
		//~ imgs = imgs[..5]; //Adjust the limit to taste
		//~ scores = score_image(imgs[*], r, g, b, 0);
		//~ sort(scores, imgs);
		//~ write("%O %O %O\n", scores[0], scores[-1], imgs[0]);
		target->paste(imgs[0][IMG], x * w, y * h);
		//~ imgs[0][USAGE]++; //Increment the usage counter to deprefer that one
	}
	write("%O\n", target);
	Stdio.write_file("meta-emote.png", Image.PNG.encode(target));
}
