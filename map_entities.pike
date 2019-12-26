//Take a list of entities and an image, and create an overlay

array parse_entity_log(string fn)
{
	array ret = ({ });
	foreach (Stdio.read_file(fn) / "\n", string line)
	{
		if (line == "") continue;
		array cur = array_sscanf(line, "%s: %f,%f,%f [%f,%f,%f - %f,%f,%f]%*[ ]%s");
		if (cur && sizeof(cur)) ret += ({cur});
	}
	return ret;
}

float map_left, map_top, map_width, map_height;
int img_width, img_height;
array(int) map_coords(array(float) pos, array(float) ofs)
{
	//The third coordinate in the position is irrelevant; map the other two
	//to pixel positions.
	//We invert the Y axis because Hammer and bitmaps are oriented differently.
	//Other than that, this is simply interpolating points in the bounds given
	//by the survival_playarea entity (which is assumed to be in the file ahead
	//of anything that actually matters).
	int x = (int)((pos[0] + ofs[0] - map_left) * img_width / map_width);
	int y = (int)((pos[1] + ofs[1] + map_top) * img_height / -map_height);
	return ({x, y});
}

constant color = ([
	//"trigger_survival_playarea": ({0, 255, 0, 200}),
	"func_hostage_rescue": ({128, 0, 0, 100}),
	"point_dz_weaponspawn": ({192, 192, 0, 230}),
	//"info_map_region": ({0, 255, 0, 230}),
]);

void handle_trigger_survival_playarea(Image.Image img, array(float) pos, array(float) min, array(float) max, string tail)
{
	map_left = pos[0] + min[0]; map_top = pos[1] + min[1];
	map_width = max[0] - min[0]; map_height = max[1] - min[1];
	//write("Map dimensions: %.2f,%.2f sz %.2f,%.2f\n", map_left, map_top, map_width, map_height);
	//write("Pixel bounds: %d,%d - %d,%d\n", @map_coords(pos, min), @map_coords(pos, max));
}

Image.Fonts.Font font;
constant map_location_names = ([
	"Tower1": "Tower One",
	//"BigBridge": "Bridge", //??
	"APC": "APC",
	"Medina": "Town", //Sirocco changed the name of this in the localizations, but kept the internal name
]);
void handle_info_map_region(Image.Image img, array(float) pos, array(float) min, array(float) max, string tail)
{
	tail -= "#SurvivalMapLocation_";
	//TODO maybe: Add a space before any capital letter (so "BoatLaunch" becomes "Boat Launch")
	//for any that aren't in the mapping
	tail = map_location_names[tail] || tail;
	Image.Image text = font->write(tail);
	[int x, int y] = map_coords(pos, min); //Should be a point entity so the mins and maxs should all be zero
	x -= text->xsize() / 2; y -= text->ysize() / 2; //Center the text
	img->paste_alpha_color(text, 0, 255, 255, x, y);
}

void generate(string map)
{
	write("Generating for dz_%s...\n", map);
	array entities = parse_entity_log(map + "_entities.log");
	//The radar images can be grabbed from steamcmd_linux/csgo/csgo/resource/overviews/dz_*_radar.dds
	Image.Image img = Image.decode(Stdio.read_file("dz_" + map + ".tiff"));
	img_width = img->xsize(); img_height = img->ysize();
	foreach (entities, array ent)
	{
		string cls = ent[0];
		array(float) pos = ent[1..3], min = ent[4..6], max = ent[7..9];
		if (function f = this["handle_" + cls]) f(img, pos, min, max, ent[10]);
		if (!color[cls]) continue;
		[int x1, int y1] = map_coords(pos, min);
		[int x2, int y2] = map_coords(pos, max);
		if (x1 == x2 && y1 == y2) //Point entity, or near enough
		{
			//Spread out in a circle, adding intensity
			for (int r = 1; r < 8; ++r)
				img->circle(x1, y1, r, r, @color[cls]);
		}
		else img->box(x1, y1, x2 + 1, y2 + 1, @color[cls]); //Simple box
	}
	Stdio.write_file("dz_" + map + "_annotated.tiff", Image.TIFF.encode(img));
}

int main()
{
	//Hack: Pick up a font. I'd rather say "give me any basic Sans Serif" but I don't
	//think the font alias system works here.
	Image.Fonts.set_font_dirs(({"/usr/share/fonts/truetype/dejavu"}));
	font = Image.Fonts.open_font("DejaVu Sans", 16, Image.Fonts.BOLD);
	generate("blacksite");
	generate("sirocco");
	generate("junglety");
}
