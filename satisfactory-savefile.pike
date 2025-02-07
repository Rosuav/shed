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
	//Huh. Unlike the vast majority of games out there, Satisfactory has info on its official wiki.
	//https://satisfactory.wiki.gg/wiki/Save_files
	//mapname is always "Persistent_Level"; sessname is what the user entered to describe the session.
	[int ver1, int ver2, int build, string mapname, string params, string sessname, int playtime] = data->sscanf("%-4c%-4c%-4c%-4H%-4H%-4H%-4c");
	if (ver1 < 13) return; //There seem to be some differences with really really old savefiles
	write("%s: %s\n", fn, sessname[..<1]);
	//visibility is "private", "friends only", etc. Not sure what the byte values are.
	//I've no idea what the session ID is at this point but it seems to stay constant for one session. It's always 22 bytes (plus the null).
	[int timestamp, int visibility, int objver, string modmeta, int modflags, string sessid] = data->sscanf("%-8c%c%-4c%-4H%-4c%-4H");
	data->read(24); //A bunch of uninteresting numbers. Possibly includes an RNG seed?
	[int cheats] = data->sscanf("%-4c"); //?? Whether AGSes are used?
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
	//Stdio.write_file("dump", decomp);
	data = Stdio.Buffer(decomp); data->read_only();
	[int sz] = data->sscanf("%-8c"); //Total size (will be equal to sizeof(data) after this returns)
	//Most of these are fixed and have unknown purpose
	[int unk10, string unk11, int zero3, int unk12, int unk13, string unk14, int unk15] = data->sscanf("%-4c%-4H%-4c%-4c%-4c%-4H%-4c");
	for (int i = 0; i < 5; ++i) {
		[string title, int unk17, int unk18, int n] = data->sscanf("%-4H%-4c%-4c%-4c");
		write("Next section: %d %O (%x/%x)\n", n, title, unk17, unk18);
		while (n--) {
			[string unk19, int unk20] = data->sscanf("%-4H%-4c");
		}
	}
	[int sublevelcount] = data->sscanf("%-4c");
	write("Sublevels: %d\n", sublevelcount);
	while (sublevelcount--) {
		[string lvlname, int sz, int count] = data->sscanf("%-4H%-8c%-4c");
		int endpoint = sizeof(data) + 4 - sz; //The size includes the count, so adjust our position accordingly
		write("Level %O size %d count %d\n", lvlname, sz, count);
		array objects = ({});
		while (count--) {
			//objtype, class, level, prop
			array obj = data->sscanf("%-4c%-4H%-4H%-4H");
			if (obj[0]) {
				//Actor
				obj += data->sscanf("%-4c%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4c"); //Transform (rotation/translation/scale)
			} else {
				//Object/component
				obj += data->sscanf("%-4H");
			}
			objects += ({obj});
		}
		[int coll] = data->sscanf("%-4c");
		while (coll--) {
			[string lvl, string path] = data->sscanf("%-4H%-4H");
			write("Collectable: %O\n", path);
		}
		//Not sure what extra bytes there might be. Also, what if we're already past this point?
		if (sizeof(data) > endpoint) data->read(sizeof(data) - endpoint);
		[int entsz, int nument] = data->sscanf("%-8c%-4c");
		endpoint = sizeof(data) + 4 - entsz;
		//Note that nument ought to be the same as the object count (and therefore sizeof(objects)) from above
		for (int i = 0; i < sizeof(objects) && i < nument; ++i) {
			[int ver, int flg, int sz] = data->sscanf("%-4c%-4c%-4c");
			write("i %d obj %O\n", i, objects[i][1]);
			int end = sizeof(data) - sz;
			if (objects[i][0]) {
				//Actor
				[string parlvl, string parpath, int components] = data->sscanf("%-4H%-4H%-4c");
				while (components--) {
					[string complvl, string comppath] = data->sscanf("%-4H-4H");
					//write("Component %O %O\n", complvl, comppath);
				}
			} else {
				//Object. Nothing interesting here.
			}
			//Properties.
			write("RAW PROPERTIES %O\n", ((string)data)[..sizeof(data) - end - 1]);
			while (sizeof(data) > end) {
				[string prop, string type] = data->sscanf("%-4H%-4H");
				if (prop == "None\0") break;
				write("Prop %O %O\n", prop, type);
				if (type == "BoolProperty\0") {
					//Special-case: Doesn't have a type string, has the value in there instead
					[int sz, int idx, int val, int zero] = data->sscanf("%-4c%-4c%c%c");
					if (sz) write("Content %O\n", data->read(sz));
				} else if ((<"ArrayProperty\0", "ByteProperty\0", "EnumProperty\0", "SetProperty\0">)[type]) {
					//Complex types have a single type
					[int sz, int idx, string type, int zero] = data->sscanf("%-4c%-4c%-4H%c");
					if (sz) write("Content %O\n", data->read(sz));
				} else if (type == "MapProperty\0") {
					//Mapping types have two types (key and value)
					[int sz, int idx, string keytype, string valtype, int zero] = data->sscanf("%-4c%-4c%-4H%-4H%c");
					if (sz) write("Content %O\n", data->read(sz));
				} else if (type == "StructProperty\0") {
					//Struct types have more padding
					[int sz, int idx, string type, int zero] = data->sscanf("%-4c%-4c%-4H%17c");
					if (sz) write("Content %O\n", data->read(sz));
				} else {
					//Primitive types have no type notation
					[int sz, int idx, int zero] = data->sscanf("%-4c%-4c%c");
					if (sz) write("Content %O\n", data->read(sz));
				}
			}
			if (sizeof(data) > end) write("REST %O\n", data->read(sizeof(data) - end));
		}
		if (sizeof(data) > endpoint) data->read(sizeof(data) - endpoint);
		[int collected] = data->sscanf("%-4c");
		write("entsz %d nument %d coll %d\n", entsz, nument, collected);
	}
	write("Remaining: %d %O\n\n", sizeof(data), data->read(128));
}

int main(int argc, array(string) argv) {
	if (argc < 2) exit(0, "Need a file to parse.\n");
	parse_savefile(argv[1..][*]);
}
