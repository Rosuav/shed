/*
Read a text EU4 savefile (use mp_autosave.eu4 by default)
Report the date and all player nations, for confirmation that it's the right file
players_countries={...}

provinces={...}
For each province, which seems to be "-125" etc:
- owner="SPA" or owner="D00" (cf players_countries)
- base_tax + base_production + base_manpower
- center_of_trade=1
- name="Palermo"


TODO: Search for upgradeable CoTs
TODO: Search for potentially-upgradeable CoTs (and list required devel for each)
*/

Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("eu4_parse.grammar");

mixed take2(mixed _, mixed ret) {return ret;}
mapping makemapping(mixed name, mixed _, mixed val) {return ([name: val]);}
mapping addmapping(mapping map, mixed name, mixed _, mixed val) {map[name] = val; return map;}
mapping makearray(mixed val) {return ({val});}
mapping addarray(array arr, mixed val) {return arr + ({val});}
mapping emptyarray() {return ({ });}

mapping parse_savefile(string data, int|void verbose) {
	sscanf(Crypto.SHA256.hash(data), "%32c", int hash);
	string hexhash = sprintf("%64x", hash);
	mapping cache = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}");
	if (cache->hash == hexhash) return cache->data;
	if (!sscanf(data, "EU4txt%s", data)) return 0;
	string|array next() {
		sscanf(data, "%[ \t\r\n]%s", string ws, data);
		if (data == "") return "";
		if (sscanf(data, "\"%[^\"]\"%s", string str, data) == 2) {
			//How are embedded quotes and/or backslashes handled?
			return ({"string", str});
		}
		if (sscanf(data, "%[-0-9.]%s", string digits, data) && digits != "") {
			return ({"string", digits});
		}
		if (sscanf(data, "%[0-9a-zA-Z_]%s", string word, data) && word != "") {
			if ((<"yes", "no">)[word]) return ({"boolean", word == "yes"});
			//Hack: this one element seems to omit the equals sign for some reason.
			if (word == "map_area_data") data = "=" + data;
			return ({"string", word});
		}
		sscanf(data, "%1s%s", string char, data); return char;
	}
	string|array shownext() {mixed tok = next(); write("%O\n", tok); return tok;}
	//while (shownext() != ""); return 0; //Dump tokens w/o parsing
	mapping ret = parser->parse(verbose ? shownext : next, this);
	Stdio.write_file("eu4_parse.json", string_to_utf8(Standards.JSON.encode((["hash": hexhash, "data": ret]))));
	return ret;
}

int main() {
	string raw = Stdio.read_file("../.local/share/Paradox Interactive/Europa Universalis IV/save games/mp_autosave.eu4"); //Assumes ISO-8859-1, which I think is correct
	mapping data = parse_savefile(raw);
	write("%O\n", data && indices(data));
}
