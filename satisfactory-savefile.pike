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
	[int unk1, int unk2, int unk3, string lbl, string params, string sessname, int playtime] = data->sscanf("%-4c%-4c%-4c%-4H%-4H%-4H%-4c");
	if (unk1 < 13) return; //There seem to be some differences with really really old savefiles
	write("%s: %s\n", fn, sessname[..<1]);
	//unk6 is always 32, unk7 is always 40. I'm reading unk6 as a byte purely as a hunch.
	//I've no idea what the session ID is at this point but it seems to stay constant for one session. It's always 22 bytes (plus the null).
	[int unk4, int unk5, int unk6, int unk7, int zero1, int zero2, string sessid] = data->sscanf("%-4c%-4c%c%-4c%-4c%-4c%-4H");
	string unk8 = data->read(76); //Possibly a bunch of numbers, hard to tell
	//????? For some reason, simply reading 77 bytes and then inflating segfaults.
	for (int i = 0; i < 2; ++i) {
		string infl;
		object gz = Gz.inflate();
		mixed ex = catch {infl = gz->inflate((string)data);};
		if (!ex) {
			data = Stdio.Buffer(gz->end_of_stream()); data->read_only();
			write("GOT A DEFLATE HEADER %d %O\n", sizeof(infl), infl[..16]);
			break;
		}
		data->read(1);
	}
	write("Remaining: %d %O\n", sizeof(data), data->read(32));
}

int main(int argc, array(string) argv) {
	if (argc < 2) exit(0, "Need a file to parse.\n");
	parse_savefile(argv[1..][*]);
}
