//Parse a Valve Data Format file

//Internals
Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("parsevdf.grammar"); //Logically this should be "vdf.grammar" but I like my shed to have files in parallel

//External API
string|mapping parse_vdf(string data) {
	string|array next() {
		if (data == "") return "";
		if (sscanf(data, "//%[^n]\n%s", string comment, data) == 2) {
			return ({"comment", comment});
		}
		if (sscanf(data, "\"%[^\"]\"%s", string str, data) == 2) {
			//How are embedded quotes and/or backslashes handled?
			return ({"string", str});
		}
		if (sscanf(data, "%[0-9]%s", string digits, data) && digits != "") {
			//Is a series of digits an integer, or should it be returned as a string?
			return ({"string", digits});
		}
		sscanf(data, "%1s%s", string char, data); return char;
	}
	while (1) {
		mixed tok = next();
		write("%O\n", tok);
		if (tok == "") return 0;
	}
	return parser->parse(next, this);
}

//Simple demo
int main(int argc, array(string) argv) {
	if (argc < 2) exit(1, "USAGE: pike %s filename.vdf", argv[0]);
	string|mapping content = parse_vdf(Stdio.read_file(argv[1]));
	write("%s\n", Standards.JSON.encode(content, 7));
}
