//Parse a Valve Data Format file

//Internals
Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("parsevdf.grammar"); //Logically this should be "vdf.grammar" but I like my shed to have files in parallel
mixed take2(mixed _, mixed ret) {return ret;}
array kv(mixed k, mixed ws, mixed v) {return ({k, v});}
array kv2(mixed ws, mixed ... args) {return kv(@args);}
mapping startmap(array kv) {return ([kv[0]: kv[1]]);}
string|mapping|array merge(string|mapping|array prev, string|mapping|array new) {
	if (!prev) return new; //Easy: nothing to merge
	//Reusing the same key with multiple strings makes an array.
	if (stringp(prev) && stringp(new)) return ({prev, new});
	//Continuing to reuse the key with string values still makes an array.
	if (arrayp(prev) && sizeof(prev) && stringp(prev[0]) && stringp(new)) return prev + ({new});
	//Reusing with multiple mappings merges the mappings. (Mutates prev for simplicity.)
	if (mappingp(prev) && mappingp(new)) {
		foreach (new; string k; mixed v) prev[k] = merge(prev[k], v);
		return prev;
	}
	//Huh. No idea.
	werror("UNABLE TO MERGE [prev=%t, new=%t]\n", prev, new);
	return prev;
}
mapping addmap(mapping map, array kv) {map[kv[0]] = merge(map[kv[0]], kv[1]); return map;}
mapping emptymapping() {return ([]);}
mixed discardkey(array kv) {return kv[1];} //A file has a meaningless key and then everything's in the value.

//External API
string|mapping|array parse_vdf(string data, int|void verbose) {
	string|array next() {
		if (data == "") return "";
		if (sscanf(data, "%[ \t\r\n]%s", string ws, data) && ws != "") return " ";
		if (sscanf(data, "//%[^\n]\n%s", string comment, data) == 2) {
			return ({"comment", String.trim(comment)}); //Returned as a separate token to aid debugging
		}
		if (sscanf(data, "\"%[^\"]\"%s", string str, data) == 2) {
			//How are embedded quotes and/or backslashes handled?
			return ({"string", str});
		}
		//Some files seem to have cvars unquoted. That would require expanding this
		//to be a full "atom" definition, but I don't know the valid alphabet for an
		//atom. It would certainly include ASCII letters and underscore, and would
		//allow non-leading digits, but is 123abc an atom?
		if (sscanf(data, "%[0-9]%s", string digits, data) && digits != "") {
			//Is a series of digits an integer, or should it be returned as a string?
			return ({"string", digits}); //Currently 123 is indistinguishable from "123".
		}
		sscanf(data, "%1s%s", string char, data); return char;
	}
	string|array shownext() {mixed tok = next(); write("%O\n", tok); return tok;}
	//while (shownext() != ""); return 0; //Dump tokens w/o parsing
	return parser->parse(verbose ? shownext : next, this);
}

//Simple demo - or simple translation to JSON, which could in itself be useful
int main(int argc, array(string) argv) {
	if (argc < 2) exit(1, "USAGE: pike %s filename.vdf\n", argv[0]);
	string|mapping|array content = parse_vdf(Stdio.read_file(argv[1]));
	write("%s\n", Standards.JSON.encode(content, 7));
}
