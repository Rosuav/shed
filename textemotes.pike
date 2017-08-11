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
	for (int y = 0; y < img->ysize(); ++y)
		for (int x = 0; x < img->xsize(); ++x)
		{
			int alpha = `+(@alpha->getpixel(x, y));
			if (alpha < 128) continue; //Ignore what's transparent (or mostly so)
			array pixel = img->getpixel(x, y);
			//Calculate the distance-squared to each focal point.
			//Whichever one is closest, that's this pixel's distance.
			int best = 256*256 * `+(@color_weight);
			foreach (focal_points, array focus)
			{
				int dist = 0;
				for (int i=0; i<3; ++i)
					dist += (pixel[i] - focus[i]) ** 2 * color_weight[i];
				if (dist < best) best = dist;
			}
			ret[sprintf("%02x%02x%02x = "+best, @img->getpixel(x, y))]++;
			ret[best]++;
			ret[SCORE] += best;
		}
	//Eliminate unusual colours from the dump display.
	//TODO: Fold them into nearby colours.
	//(They still affect the final score.)
	foreach (ret; string col; int count) if (count < 10) m_delete(ret, col);
	return ret;
}

int main()
{
	array all_emotes = Standards.JSON.decode_utf8(Stdio.read_file("emote_list.json"))->emoticons;
	//NOTE: The emote info contains an *array* of images, but every single
	//one seems to have one element in that array.
	Array.shuffle(all_emotes);
	//Pick up some emotes we don't have and download them.
	int dl = 100; //Once the limit gets exhausted, stop downloading and just analyze what we have.
	int checked = 0;
	if (dl) foreach (all_emotes, mapping emote)
	{
		++checked;
		string fn = emote->regex + ".png";
		if (file_stat(fn)) continue; //Assume that any file is the right file.
		write("Downloading %s...\e[K\r", emote->regex);
		string data = Protocols.HTTP.get_url_data(emote->images[0]->url);
		if (!data) {write("ERROR LOADING %s\n", emote->regex); continue;}
		Stdio.write_file(fn, data);
		if (!--dl) break;
	}
	write("Checked %d.\e[K\n", checked);
	array emotes = ({ });
	foreach (sort(get_dir()), string fn) if (has_suffix(fn, ".png"))
	{
		mapping info = find_colors(fn);
		if (!info) continue;
		//write("%s: %O\n", fn-".png", info);
		emotes += ({ ({info[SCORE], fn-".png"}) });
	}
	sort(emotes);
	write("%{[%d] %s\n%}", emotes[..9]);
	Stdio.write_file("top10.html", sprintf("%{<li><img src=\"%s.png\"> %<s\n%}", emotes[..29][*][1]));
}
