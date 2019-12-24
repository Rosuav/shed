//Take a list of entities and an image, and create an overlay

array parse_entity_log(string fn)
{
	array ret = ({ });
	foreach (Stdio.read_file(fn) / "\n", string line)
	{
		if (line == "") continue;
		array cur = array_sscanf(line, "%s: %f,%f,%f [%f,%f,%f - %f,%f,%f]");
		if (cur && sizeof(cur)) ret += ({cur});
	}
	return ret;
}

array(int) map_coords(array(float) pos, array(float) ofs)
{
	//The third coordinate in the position is irrelevant; map the other two
	//to pixel positions.
	int x = (int)((pos[0] + ofs[0] + 8192.0) * 1024 / 16384); //Add offset, multiply by pixel width, divide by hammer unit width
	int y = (int)((pos[1] + ofs[1] - 8192.0) * 1024 / -16384); //Ditto height
	return ({x, y});
}

constant color = ([
	"func_hostage_rescue": ({255, 255, 0, 100}),
	"point_dz_weaponspawn": ({0, 255, 255, 0}),
]);

int main()
{
	//TODO: Parse args
	array entities = parse_entity_log("../tf2server/steamcmd_linux/csgo/csgo/entities.log");
	Image.Image img = Image.decode(Stdio.read_file("../tmp/Map_dz_blacksite.tiff"));
	foreach (entities, array ent)
	{
		string cls = ent[0];
		array(float) pos = ent[1..3], min = ent[4..6], max = ent[7..9];
		if (!color[cls]) continue;
		[int x1, int y1] = map_coords(pos, min);
		[int x2, int y2] = map_coords(pos, max);
		//write("%s: %d,%d - %d,%d\n", cls, x1, y1, x2, y2);
		img->box(x1, y1, x2 + 1, y2 + 1, @color[cls]);
	}
	Stdio.write_file("../tmp/dz_blacksite_annotated.tiff", Image.TIFF.encode(img));
}
