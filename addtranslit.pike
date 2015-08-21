int main(int argc,array(string) argv)
{
	if (argc<3) exit(0,"USAGE: %s inputfile language [outputfile]\nIf outputfile is omitted, inputfile will be replaced.\n");
	if (argc<4) argv+=({argv[1]});
	function translit=((object)"translit.pike")[argv[2]+"_to_Latin"];
	if (!translit) exit(0,"Unrecognized language %O (check case)\n",argv[2]);
	array(string) lines=utf8_to_string(Stdio.read_file(argv[1]))/"\n";
	foreach (lines;int i;string line)
	{
		string other=translit(line);
		if (other!=line) lines[i]+="\n"+other;
	}
	Stdio.write_file(argv[3],string_to_utf8(lines*"\n"));
}
