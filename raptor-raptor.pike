int main()
{
	//Use 1.0, 2.0, or 3.0 to select the resolution, or pick a different emote.
	// wget https://static-cdn.jtvnw.net/emoticons/v1/550688/2.0 -O hallwaLurk.png
	string data = Stdio.read_file("hallwaLurk.png");
	Image.Image raptor = Image.PNG.decode(data);
	int w = raptor->xsize(), h = raptor->ysize();
	Image.Image alpha = Image.PNG.decode_alpha(data);
	Image.Image old_raptor = raptor->grey();
	Image.Image metaraptor = Image.Image(w * w, h * h, 204, 204, 204);
	for (int x = 0; x < w; ++x) for (int y = 0; y < h; ++y)
	{
		array pixel = raptor->getpixel(x, y);
		Image.Image colorraptor = old_raptor->color(@pixel);
		metaraptor->paste_mask(colorraptor, alpha, x * w, y * h);
	}
	write("%O\n", metaraptor);
	Stdio.write_file("metaraptor.png", Image.PNG.encode(metaraptor));
}
