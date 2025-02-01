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
	string unk8 = data->read(28); //Possibly a bunch of numbers, hard to tell
	//The rest of the file is a series of compressed chunks. Each blob of deflated data has a
	//header prepended which is 49 bytes long.
	string decomp = "";
	while (sizeof(data)) {
		//Chunk header is a fixed eight byte string
		//Oddly, the inflated size is always 131072, even on the last chunk, which has whatever's left.
		//A lot of this is guesses, esp since most of this seems to be fixed format (eg type is always 3,
		//but I'm guessing that's a one-byte marker saying "gzipped"). In the last 24 bytes, there seem
		//to be more copies of the same information, no idea why.
		//werror("%O\n", ((string)data)[..20]);
		[string chunkhdr, int inflsz, int zero1, int type, int deflsz, int zero2, string unk9] = data->sscanf("%8s%-4c%-4c%c%-4c%-4c%24s");
		//????? For some reason, Pike segfaults if we don't first probe the buffer like this.
		//So don't remove this 'raw =' line even if raw itself isn't needed.
		string raw = (string)data;
		object gz = Gz.inflate();
		decomp += gz->inflate((string)data);
		data = Stdio.Buffer(gz->end_of_stream()); data->read_only();
	}
	//Alright. Now that we've unpacked all the REAL data, let's get to parsing.
	data = Stdio.Buffer(decomp); data->read_only();
	[int sz] = data->sscanf("%-8c"); //Total size (will be equal to sizeof(data) after this returns)
	[int unk10, string unk11, int zero3, int unk12, int unk13, string unk14, int unk15] = data->sscanf("%-4c%-4H%-4c%-4c%-4c%-4H%-4c");
	while (sizeof(data)) {
		[string title, int unk17, int unk18, int n] = data->sscanf("%-4H%-4c%-4c%-4c");
		write("%O %O %d\n", unk17, unk18, n);
		write("Next section: %d %O\n", n, title);
		while (n--) {
			[string unk19, int unk20] = data->sscanf("%-4H%-4c");
			//write("[%d] %O %O\n", n, unk19, unk20);
		}
	}
	write("Remaining: %d %O\n", sizeof(data), data->read(32));
}

int main(int argc, array(string) argv) {
	if (argc < 2) exit(0, "Need a file to parse.\n");
	parse_savefile(argv[1..][*]);
}
