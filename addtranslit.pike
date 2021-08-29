int main(int argc,array(string) argv)
{
	if (argc<3) exit(0,"USAGE: %s inputfile language [outputfile]\nIf outputfile is omitted, inputfile will be replaced.\n");
	if (argc<4) argv+=({argv[1]});
	function translit=((object)"translit.pike")[argv[2]+"_to_Latin"];
	if (!translit) exit(0,"Unrecognized language %O (check case)\n",argv[2]);
	if (argv[1] == "-") {
		write("Enter English text, followed by a dot on a blank line:\n");
		array eng = ({ });
		while (string l = Stdio.stdin.gets()) {
			if (l == ".") break;
			eng += ({String.trim(utf8_to_string(l))});
		}
		write("\n\nEnter %s text, followed by a dot or EOF:\n", argv[2]);
		array other = ({ });
		while (string l = Stdio.stdin.gets()) {
			if (l == ".") break;
			other += ({String.trim(utf8_to_string(l))});
		}
		if (sizeof(eng) != sizeof(other)) exit(1, "Blocks must be same length\n");
		Stdio.File out = Stdio.File(argv[3], "wac");
		foreach (eng; int i; string e) {
			if (e == "" && other[i] == "") {out->write("\n"); continue;}
			if (has_suffix(argv[3], ".srt")) out->write("\n00:00:00,750 --> 00:00:00,500\n");
			out->write(string_to_utf8(e + "\n" + other[i] + "\n" + translit(other[i]) + "\n"));
		}
		out->close();
		return 0;
	}
	array(string) lines = utf8_to_string(Stdio.read_file(argv[1])) / "\n";
	foreach (lines;int i;string line)
	{
		string other=translit(line);
		if (other!=line) lines[i]+="\n"+other;
	}
	Stdio.write_file(argv[3],string_to_utf8(lines*"\n"));
}
