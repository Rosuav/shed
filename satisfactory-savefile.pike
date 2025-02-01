//I know the AnthorNet tool can read these files, but I'm starting fresh
//Main goal: List all detritus and all hard drive requirements.
//1) Does detritus get added to the savefile only once you approach it?
//2) Is detritus always the same - that is, is initial item distribution part of the map, or randomized?
//3) Can I see some marker that says "this sector hasn't had its items loaded in yet"?

//Strings are stored as null-terminated Hollerith strings, which seems redundant. (The null is included in the length.)
//Integers, including string lengths, are all 32-bit little-endian.
void parse_savefile(string fn) {
	Stdio.Buffer data = Stdio.Buffer(Stdio.read_file(fn));
	data->read_only();
	//unk1 and unk2 may be some sort of version number.
	//unk3 seems to remain the same for saves in the same session - maybe RNG seed??
	//lbl is always "Persistent_Level"; sessname is what the user entered to describe the session.
	[int unk1, int unk2, int unk3, string lbl, string params, string sessname] = data->sscanf("%-4c%-4c%-4c%-4H%-4H%-4H");
	write("%s: %s\n", fn, sessname[..<1]);
}

int main(int argc, array(string) argv) {
	if (argc < 2) exit(0, "Need a file to parse.\n");
	parse_savefile(argv[1..][*]);
}
