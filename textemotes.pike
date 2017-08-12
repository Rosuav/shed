//Attempt to find the text emotes on Twitch
//These are similar to brollI "I AM" and its friends.

//Focal points taken from kittenzSew; impgrrlMuch is nearly the same;
//brollI is a bit different but close.
array focal_points = ({
	({80, 106, 239}),
	({192, 80, 239}),
	({236,  0, 140}),
});
array color_weight = ({87, 127, 41}); //Color weighting as per grey()
//array color_weight = ({1,1,1}); //Flat color weighting

constant SCORE = "- Score -"; //Is a string for the sake of the %O display

mapping(string|int:int) find_colors(string fn)
{
	Image.Image img, alpha;
	if (catch {
		mapping m = Image.PNG._decode(Stdio.read_file(fn));
		img = m->image; alpha = m->alpha;
	}) return 0; //Decoding errors happen sometimes. Some images are actually JPGs.
	mapping(string|int:int) ret = ([]);
	int pixels = 0;
	array(int) aimed_at = allocate(sizeof(focal_points));
	for (int y = 0; y < img->ysize(); ++y)
		for (int x = 0; x < img->xsize(); ++x)
		{
			int a = alpha ? `+(@alpha->getpixel(x, y)) : 768;
			if (a < 128) continue; //Ignore what's transparent (or mostly so)
			array pixel = img->getpixel(x, y);
			//Calculate the distance-squared to each focal point.
			//Whichever one is closest, that's this pixel's distance.
			int best = 256*256 * `+(@color_weight);
			int focalpoint;
			foreach (focal_points; int which; array focus)
			{
				int dist = 0;
				for (int i=0; i<3; ++i)
					dist += (pixel[i] - focus[i]) ** 2 * color_weight[i];
				if (dist < best) {focalpoint = which; best = dist;}
			}
			aimed_at[focalpoint]++;
			ret["F" + focalpoint]++;
			ret[sprintf("%02x%02x%02x = "+best, @img->getpixel(x, y))]++;
			ret[best]++;
			ret[SCORE] += best;
			++pixels;
		}
	if (pixels) //because brollC :D
	{
		//Take the average distance of non-transparent pixels, to avoid skewing towards
		//mostly-transparent images.
		ret[SCORE] /= pixels;
		//Multiply by the highest proportion to land on a single focal point. This
		//means that images using exactly one colour (which thus attach every pixel
		//to the same focal point) will score higher (worse) than those which use
		//all three colours fairly evenly.
		ret[SCORE] = ret[SCORE] * max(@aimed_at) / max(min(@aimed_at), 1);
	}
	else ret[SCORE] = 1<<256; //Actually I've found *four* entirely-transparent emotes. Suppress them.
	//Eliminate unusual colours from the dump display.
	//TODO: Fold them into nearby colours.
	//(They still affect the final score.)
	foreach (ret; string col; int count) if (count < 10) m_delete(ret, col);
	return ret;
}

array parse_images(array(string) files, int start, int step)
{
	write("Starting thread %d/%d\n", start, step);
	array results = ({ });
	for (int i = start; i < sizeof(files); i += step)
	{
		mapping info = find_colors(files[i]);
		if (!info) continue;
		//write("%s: %O\n", fn-".png", info);
		results += ({ ({info[SCORE], files[i]-".png"}) });
	}
	return results;
}

int main()
{
	array all_emotes = Standards.JSON.decode_utf8(Stdio.read_file("emote_list.json"))->emoticons;
	//NOTE: The emote info contains an *array* of images, but every single
	//one seems to have one element in that array.
	Array.shuffle(all_emotes);
	//Pick up some emotes we don't have and download them.
	int dl = 15000; //Once the limit gets exhausted, stop downloading and just analyze what we have.
	//dl = sizeof(all_emotes) - sizeof(glob("*.png", get_dir())); //Get the lot!
	int checked = 0;
	if (dl) foreach (all_emotes, mapping emote)
	{
		if (!emote->images[0]->url) continue; //A handful of emotes have no URL. Why?
		++checked;
		string fn = replace(emote->regex, "/", "\xEF\xBC\x8F") + ".png"; //A slash in a file name becomes "／", UTF-8 encoded.
		if (file_stat(fn)) continue; //Assume that any file is the right file.
		write("[%d] Downloading %s...\e[K\r", dl, emote->regex);
		string data = Protocols.HTTP.get_url_data(emote->images[0]->url);
		if (!data) {write("ERROR LOADING %s\e[K\n", emote->regex); continue;}
		Stdio.write_file(fn, data);
		if (!--dl) break;
	}
	write("Checked %d.\e[K\n", checked);
	array(string) files = sort(glob("*.png", get_dir()));
	#if 0
	array THREADS = enumerate(4); //For some reason, this doesn't work with the array directly in the parameters. (???)
	array emotes = `+(@Thread.Thread(parse_images, files, THREADS[*], sizeof(THREADS))->wait());
	#else
	//Hmm. With one thread, we're pegging one CPU core. But with multiple, we just divide the job
	//across multiple cores, with no two cores being busy at the same time. So there's some sort
	//of locking going on, and the overall task is slower with threads than without.
	//Let's just do it without threads, then. :(
	array emotes = parse_images(files, 0, 1);
	#endif
	emotes -= ({0});
	write("Parsed %d/%d.\n", sizeof(emotes), sizeof(files));
	sort(emotes);
	write("%{[%d] %s\n%}", emotes[..9]);
	Stdio.write_file("most_similar.html", sprintf("%{<li><img src=\"%s.png\"> %<s\n%}", emotes[..99][*][1]));
}
