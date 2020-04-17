//Take a list of entities and an image, and create an overlay

//TODO: Make these configurable eg by environment variable
constant CSGO_SERVER_ROOT = "/home/rosuav/tf2server/steamcmd_linux/csgo/csgo";
constant WORK_DIR = "/tmp";

mixed _ignore_ = Gz.crc32; //Force the Gz module to be loaded, thus activating Image.PNG

//Returns [mapname, entities]
array(string|array) parse_entity_log(string fn)
{
	string mapname = 0;
	array ret = ({ });
	foreach (Stdio.read_file(fn) / "\n", string line)
	{
		if (line == "") continue;
		if (sscanf(line, "Searching dz_%s for ", string map) && map) mapname = map;
		array cur = array_sscanf(line, "%s: %f,%f,%f [%f,%f,%f - %f,%f,%f]%*[ ]%s");
		if (cur && sizeof(cur)) ret += ({cur});
	}
	return ({mapname, ret});
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
	"info_map_region_boundary": ({0, 255, 0}),
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
	"BigBridge": "Bridge", "FishingDocks": "Fishing", "MilitaryBase": "Base", "RadarDome": "Dome",
	"OldVillage": "Village", "StorageTanks": "Tanks", "PipelineBeach": "Pipelines", "PumpStation": "Pumps",
	"Tower1": "Tower One", "LittleW": "Dubyah",
	"APC": "APC", //To prevent it being translated to "A P C" (see the regex below)
	"Medina": "Town", //Sirocco changed the name of this in the localizations, but kept the internal name
]);
mapping(string:multiset(string)) permap_uninteresting = ([
	//Blacksite would be improved by adding another region at -925.00,-800.00 called "Hut".
	"blacksite": (<"Bridge", "Cove", "Trench", "Hatch", "Forest", "Canyon", "Overlook", "Boardwalk", "Docks", "Crane">),
	"sirocco": (<"Catwalk", "Pumps", "Dome", "Fishing">),
	"junglety": (<"APC", "Bridge">),
]);
multiset uninteresting = (< >);
array locations, drawme;
void handle_info_map_region(Image.Image img, array(float) pos, array(float) min, array(float) max, string tail)
{
	tail -= "#SurvivalMapLocation_";
	tail = map_location_names[tail] || String.trim(Regexp.replace("[A-Z]", tail, lambda(string s) {return " " + s;}));
	[int x, int y] = map_coords(pos, min); //Should be a point entity so the mins and maxs should all be zero
	drawme += ({ ({ tail, x, y}) });
	if (uninteresting[tail]) return;
	//Find the nearest other location. However far it is to there, half that
	//distance is the "grab radius" of this location. Note that, since we do
	//these sequentially, we may also need to update the other location's
	//radius. (We store distance squared, not distance, for convenience.)
	float best = map_width * map_height + 1;
	foreach (locations, mapping loc)
	{
		float dist = (loc->pos[0] - pos[0]) ** 2 + (loc->pos[1] - pos[1]) ** 2;
		float radius = dist / 4;
		if (radius < best) best = radius;
		if (radius < loc->radius) loc->radius = radius;
	}
	locations += ({ (["pos": pos, "name": tail, "loot": 0, "near": 0, "radius": best]) });
}

void handle_point_dz_weaponspawn(Image.Image img, array(float) pos, array(float) min, array(float) max, string tail)
{
	float best = map_width * map_height + 1; //distance-squared
	mapping bestloc;
	foreach (locations, mapping loc)
	{
		float dist = (loc->pos[0] - pos[0]) ** 2 + (loc->pos[1] - pos[1]) ** 2;
		if (dist < best) {best = dist; bestloc = loc;}
	}
	if (best > bestloc->maxdist) bestloc->maxdist = best;
	if (best > bestloc->radius) bestloc->near++; else bestloc->loot++;
}

void generate()
{
	//By default, we get the map name from the single entity file. TODO: Allow
	//'snapshot' entity files for when we're doing heavy changes.
	[string map, array entities] = parse_entity_log(CSGO_SERVER_ROOT + "/entities.log");
	uninteresting = permap_uninteresting[map];
	if (!uninteresting) error("Unknown map file %O\n", map);
	write("Generating for dz_%s...\n", map);
	string pngfile = WORK_DIR + "/dz_" + map + ".png";
	string png = Stdio.read_file(pngfile);
	if (!png)
	{
		string dds = sprintf("%s/resource/overviews/dz_%s_radar.dds", CSGO_SERVER_ROOT, map);
		int rc = Process.create_process(({"convert", dds, pngfile}))->wait();
		if (rc) error("Error converting DDS to PNG [rc=%d]\n", rc);
		png = Stdio.read_file(pngfile);
		if (!png) error("Conversion from DDS to PNG resulted in no file\n");
	}
	Image.Image img = Image.decode(png);
	img_width = img->xsize(); img_height = img->ysize();
	locations = drawme = ({ }); //Reset the locations for each new map
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
	foreach (drawme, [string txt, int x, int y])
	{
		Image.Image text = font->write(txt, "");
		x -= text->xsize() / 2; y -= text->ysize() / 2; //Center the text
		img->paste_alpha_color(text, 0, 0, 0, x + 2, y + 2);
		img->paste_alpha_color(text, 128, 255, 255, x, y);
	}
	foreach (locations, mapping loc)
	{
		int r = (int)((loc->radius * img_width * img_height / map_width / map_height) ** 0.5);
		[int x, int y] = map_coords(loc->pos, ({0, 0, 0}));
		img->circle(x, y, r, r, @color["info_map_region_boundary"]);
		Image.Image text = font->write("", sprintf("%d + %d", loc->loot, loc->near));
		x -= text->xsize() / 2; y -= text->ysize() / 2; //Center the text
		img->paste_alpha_color(text, 0, 0, 0, x + 2, y + 2);
		img->paste_alpha_color(text, 0, 255, 255, x, y);
	}
	write("%d locations.\n", sizeof(locations));
	Stdio.write_file("entity_map/dz_" + map + "_annotated.png", Image.PNG.encode(img));
}

int main()
{
	//Hack: Pick up a font. I'd rather say "give me any basic Sans Serif" but I don't
	//think the font alias system works here.
	Image.Fonts.set_font_dirs(({"/usr/share/fonts/truetype/dejavu"}));
	font = Image.Fonts.open_font("DejaVu Sans", 18, Image.Fonts.BOLD);
	generate();
}
