//De-overlap SRT entries to allow a shorthand entry notation
//00:00:31,750 --> 00:00:40,500
//00:00:00,750 --> 00:00:45,500
//00:00:00,750 --> 00:00:51,500
//becomes
//00:00:31,750 --> 00:00:40,500
//00:00:40,750 --> 00:00:45,500
//00:00:45,750 --> 00:00:51,500

int main(int argc, array(string) argv) {
	if (argc < 2) exit(1, "USAGE: pike %s somefile.srt\n", argv[0]);
	array lines = Stdio.read_file(argv[1]) / "\n";
	string lastpoint = "00:00:00";
	foreach (lines; int i; string line) {
		sscanf(line, "%[0-9:,] --> %[0-9:,]", string from, string to);
		if (!from || !to) continue;
		sscanf(from, "%s,%d", string point, int offset);
		if (point == "00:00:00") lines[i] = sprintf("%s,%d --> %s", lastpoint, offset, to);
		sscanf(to, "%s,%*d", lastpoint);
	}
	Stdio.write_file(argv[1], lines * "\n");
}
