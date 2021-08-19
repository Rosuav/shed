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


Grammar:

* First line "EU4txt\n"
* Everything else is name=value
* Value is one of:
  - 1676.1.1
  - "mp_autosave.eu4"
  - { name=value... }
  - { value value value... }
* Names always (seem to) start with letter or hyphen
* Values start with a digit, a quote, or a brace, or are the word "yes" or "no"

TODO: Build grammar
TODO: Parse file to nested mapping
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
	if (!sscanf(data, "EU4txt%s", data)) return 0;
	string|array next() {
		if (data == "") return "";
		sscanf(data, "%[ \t\r\n]%s", string ws, data);
		if (sscanf(data, "\"%[^\"]\"%s", string str, data) == 2) {
			//How are embedded quotes and/or backslashes handled?
			return ({"string", str});
		}
		if (sscanf(data, "%[0-9.]%s", string digits, data) && digits != "") {
			return ({"string", digits});
		}
		sscanf(data, "%1s%s", string char, data); return char;
	}
	string|array shownext() {mixed tok = next(); write("%O\n", tok); return tok;}
	//while (shownext() != ""); return 0; //Dump tokens w/o parsing
	return parser->parse(verbose ? shownext : next, this);
}

int main() {
	mapping data = parse_savefile(Stdio.read_file("../.local/share/Paradox Interactive/Europa Universalis IV/save games/mp_autosave.eu4"));
	write("%O\n", data && indices(data));
}
