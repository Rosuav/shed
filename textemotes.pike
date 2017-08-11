//Attempt to find the text emotes on Twitch
//These are similar to brollI "I AM" and its friends.

//Focal points taken from kittenzSew; impgrrlMuch is nearly the same;
//brollI is a bit different but close.
array focal_points = ({
	({80, 106, 239}),
	({192, 80, 239}),
	({236,  0, 140}),
});

constant SCORE = "- Score -"; //Is a string for the sake of the %O display

mapping(string:int) find_colors(string fn)
{
	mapping m = Image.PNG._decode(Stdio.read_file(fn));
	Image.Image img = m->image, alpha = m->alpha;
	mapping(string:int) ret = ([]);
	for (int y = 0; y < img->ysize(); ++y)
		for (int x = 0; x < img->xsize(); ++x)
		{
			int alpha = `+(@alpha->getpixel(x, y));
			if (alpha < 128) continue; //Ignore what's transparent (or mostly so)
			array pixel = img->getpixel(x, y);
			//Calculate the distance-squared to each focal point.
			//Whichever one is closest, that's this pixel's distance.
			int best = 200000;
			foreach (focal_points, array focus)
			{
				int dist = 0;
				for (int i=0; i<3; ++i)
					dist += (pixel[i] - focus[i]) ** 2;
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
	array emotes = ({ });
	foreach (sort(get_dir()), string fn) if (has_suffix(fn, ".png"))
	{
		mapping info = find_colors(fn);
		write("%s: %O\n", fn-".png", info);
		emotes += ({ ({info[SCORE], fn-".png"}) });
	}
	sort(emotes);
	write("%{[%d] %s\n%}", emotes);
}
