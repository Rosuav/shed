//Parse savefiles from.... I dunno what, but whatever Rebuild 3 is. They're deflated XML with a header.

int main(int argc, array(string) argv) {
	if (argc < 2) exit(1, "USAGE: pike %s filename\n", argv[0]);
	foreach (argv[1..], string fn) {
		string data = Stdio.read_file(fn);
		if (!data) {write("File not found or unreadable: %O\n", fn); continue;}
		sscanf(data, "%*2c%4c%*10c%2H%*4c%c%*6c%s", int size, string name, int type, string comp);
		//size is the same as file size after those initial six bytes
		//name is the file name minus extension
		//write("%O %s\n", type, fn);
		if (type == 7) {
			//7 for compressed XML, 9 for ... something else, not compressed
			string decomp;
			if (catch (decomp = Gz.inflate()->inflate(comp)))
				//Sometimes there's one more byte, not sure why.
				decomp = Gz.inflate()->inflate(comp[1..]);
			sscanf(decomp, "%c%2c%s", int type, int size, string data);
			write("%s\n", data);
		}
	}
}
