//Parse savefiles from.... I dunno what, but whatever Rebuild 3 is. They're deflated XML with a header.
/*
Perk IDs:
21: Firearms Training
31: Hoarder
109: Devout
111: Camper
151: Stinky
5003,503: [L]Doctor, Immune
601,153,509,22: Tough, Melee Training, probably one of them is a unique Diane Moone perk
156,41: Light Sleeper, Redecorator
11,12: Negotiator, Preacher
*/

/*
There seems to be some sort of checksum or something. Having trouble finding it though.
Attempting to rebuild (heh heh) the file without changes results in the file being corrupt.
There are quite a few unknown bytes here and there.
*/

int main(int argc, array(string) argv) {
	if (argc < 2) exit(1, "USAGE: pike %s filename\n", argv[0]);
	foreach (argv[1..], string fn) {
		string data = Stdio.read_file(fn);
		if (!data) {write("File not found or unreadable: %O\n", fn); continue;}
		/*
		for (int i = 0; i < sizeof(data); ++i) {
			for (int j = i; j < sizeof(data); ++j) {
				int crc = Gz.crc32(data[i..j]);
				foreach (({sprintf("%4c", crc), sprintf("%-4c", crc)}), string findme) {
					int pos = search(data, findme);
					if (pos > -1 && pos < 100) write("FOUND: %d-%d %d %s\n", i, j, pos, String.string2hex(findme));
				}
			}
		}
		*/
		sscanf(data, "%2c%4c%10c%2H%4c%c%6c%s", int unk1, int size, int unk2, string name, int unk3, int type, int unk4, string comp);
		//unk1 seems to be fixed 191 (00 BF)
		//size is the same as file size after those initial six bytes
		//unk2 has four letters of ASCII that seem to be fixed, then some low bytes (mostly zeroes)
		//name is the file name minus extension
		write("%s: %O\n", fn, ({unk1, size, unk2, name, unk3, type, unk4}));
		if (type == 7) {
			//7 for compressed XML, 9 for ... something else, not compressed
			object defl = Gz.inflate();
			string decomp, spare = "";
			if (catch (decomp = defl->inflate(comp))) {
				//Sometimes there's one more byte, not sure why.
				spare = comp[..0];
				defl = Gz.inflate(); decomp = defl->inflate(comp[1..]);
			}
			sscanf(decomp, "%c%2c%s", int subtype, int sz, string data);
			//decomp = replace(decomp, "<perkIds>31,109</perkIds>", "<perkIds>31,156</perkIds>");
			//comp = spare + Gz.deflate()->deflate(data) + defl->end_of_stream();
			//string raw = sprintf("%10c%2H%4c%c%6c%s", unk2, name, unk3, type, unk4, comp);
			//Stdio.write_file(fn, sprintf("%2c%4H", 191, raw));
		}
	}
}
