//Attempt to find the text emotes on Twitch
//These are similar to brollI "I AM" and its friends.
//curl -H 'Accept: application/vnd.twitchtv.v5+json' -H 'Client-ID: uo6dggojyb8d6soh92zknwmi5ej1q2' -X GET 'https://api.twitch.tv/kraken/chat/emoticons' >emote_list.json
//If a human-readable version is desired:
//python3 -m json.tool <emote_list.json >emote_human.json
//Pretty-prints it at roughly double the file size. Either version is acceptable to this script.

//Focal points taken from kittenzSew; impgrrlMuch is nearly the same;
//brollI is a bit different but close.
array kittenz = ({
	({80, 106, 239}),
	({192, 80, 239}),
	({236,  0, 140}),
});
//Fourth (optional) focal point from impgrrlMuch. Improves some results; worsens others.
array impgrrl = kittenz + ({({153, 50, 172})});

//TockCustom has a darker set of colours.
array tockBulge = ({
	({102, 45, 145}),
	({127, 63, 152}),
	({146, 39, 143}),
	({236, 0, 140}),
	({239, 89, 161}),
});
array tockMoist = tockBulge + ({({169, 23, 143})});

//Select which set of focal points to use.
array focal_points = kittenz;

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
		//NOTE: The fourth focal point is optional; three-letter emotes (SEW, IAM)
		//don't use it. So don't penalize an emote for using only three colours.
		ret[SCORE] = ret[SCORE] * max(@aimed_at) / max(min(@aimed_at[..2]), 1);
	}
	/* Actually there are a bunch of transparent emotes. So suppress them.
	bboyHair (bald/shaved streamer), brollC, ferretNULL, fireBreak,
	kgothTENBUCKS/kgothTWENTYFIVEBUCKS (streamer doesn't like tier emotes),
	m4xEmpty, micNone, pvp0, ruyuB, smithNothing, teeveeBlank, tgm300,
	twingeBlank. There are also near-transparent ones - ignore them too.
	*/
	else ret[SCORE] = 1<<256;
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
		if (sizeof(files) < 20) write("%s: %O\n", files[i]-".png", info);
		results += ({ ({info[SCORE], files[i]-".png"}) });
	}
	return results;
}

int main(int argc, array(string) argv)
{
	array all_emotes = Standards.JSON.decode_utf8(Stdio.read_file("emote_list.json"))->emoticons;
	//NOTE: The emote info contains an *array* of images, but every single
	//one seems to have one element in that array.
	if (argc > 2 && argv[1] == "--results")
	{
		//Reparse the result file(s) into a combined file
		mapping(string:string) emote_url = ([]);
		foreach (all_emotes, mapping emote) emote_url[emote->regex] = emote->images[0]->url;
		array columns = ({ });
		foreach (argv[2..], string resultfile)
		{
			sscanf(Stdio.read_file(resultfile), "Colors:%{ %[a-z0-9]%}<br>\n%{<li><img src=\"%s.png\"> %*s\n%}", array cols, array emotes);
			array col = ({sprintf("<td>Color matches: %{<div style=\"background-color: #%s\"></div>%}</td>", cols)});
			foreach (emotes, [string emote])
				col += ({sprintf("<td><img src=\"%s\" alt=\"%s\"> %<s</td>", emote_url[emote] || "(none)", emote)});
			columns += ({col});
		}
		Stdio.write_file(argv[0] - ".pike" + ".html", sprintf(#"<!doctype html>
<head>
<meta charset=\"utf-8\">
<title>Text emotes</title>
<style>
div {
	display: inline-block;
	width: 28px;
	height: 28px;
}
</style>
</head>
<body>
<p>
The following is the result of a great emote search, looking for the text emotes like 'I AM', 'SEW', 'MUCH', etc.
Similarity is determined by their use of colours; but the emotes are not all perfectly consistent - TockCustom's
'MOIST' and 'BULGE' emotes use darker shades, for instance. Nonetheless, the search has proved somewhat fruitful;
below you will see the algorithm's top 100 results.
</p>
<p>Source code is all on <a href=\"https://github.com/Rosuav/shed/blob/master/textemotes.pike\">GitHub</a>.</p>
<table border=1>
%{<tr>%s</tr>
%}</table></body>", Array.transpose(columns)[*]*""));
		return 0;
	}
	Array.shuffle(all_emotes);
	//Pick up some emotes we don't have and download them.
	int dl = 15000; //Once the limit gets exhausted, stop downloading and just analyze what we have.
	//dl = sizeof(all_emotes) - sizeof(glob("*.png", get_dir())); //Get the lot!
	int checked = 0;
	int downloaded = 0;
	if (dl) foreach (all_emotes, mapping emote)
	{
		if (!emote->images[0]->url) continue; //A handful of emotes have no URL. Why?
		++checked;
		string fn = replace(emote->regex, "/", "\xEF\xBC\x8F") + ".png"; //A slash in a file name becomes "／", UTF-8 encoded.
		if (file_stat(fn)) continue; //Assume that any file is the right file.
		++downloaded;
		if (has_value(argv, "--count")) continue;
		write("[%d] Downloading %s...\e[K\r", dl, emote->regex);
		string data = Protocols.HTTP.get_url_data(emote->images[0]->url);
		if (!data) {write("ERROR LOADING %s\e[K\n", emote->regex); continue;}
		Stdio.write_file(fn, data);
		if (!--dl) break;
	}
	write("Checked %d, downloaded %d.\e[K\n", checked, downloaded);
	if (has_value(argv, "--count")) return 0;
	array(string) files = sort(glob("*.png", get_dir()));
	if (argc > 1) files = argv[1..]; //Process a specific set of files for debug purposes
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
	Stdio.write_file("most_similar.html", sprintf("Colors:%{ %02x%02x%02x%}<br>\n%{<li><img src=\"%s.png\"> %<s\n%}", focal_points, emotes[..99][*][1]));
}
