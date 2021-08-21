/*
Read a text EU4 savefile (use mp_autosave.eu4 by default)
Currently scans for upgradeable Centers of Trade, since they're hard to find.
Could search for anything else of interest.

* Find coal-producing provinces and show whether they have Furnace, have other Mfg, or lack the dev to build
*/

Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("eu4_parse.grammar");

mixed take2(mixed _, mixed ret) {return ret;}
mapping makemapping(mixed name, mixed _, mixed val) {return ([name: val]);}
mapping addmapping(mapping map, mixed name, mixed _, mixed val) {
	//Note that, sometimes, an array is defined by simply assigning multiple times.
	//I have no way of distinguishing an array of one element in that form from a
	//simple entry; and currently, since this is stateless, I can't properly handle
	//an array of arrays.
	if (arrayp(map[name])) map[name] += ({val});
	else if (map[name]) map[name] = ({map[name], val});
	else map[name] = val;
	return map;
}
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
	if (!data) exit(1, "Unable to parse save file (see above for errors, hopefully)\n");
	write("\nCurrent date: %s\n", data->date);
	array players = data->players_countries / 2;
	multiset player_tags = (multiset)players[*][1];
	write("Players:%{ %s (%s)%}\n\n", players);
	array maxlvl = ({ }), upgradeable = ({ }), developable = ({ });
	foreach (data->provinces; mixed id; mapping prov) {
		if (!player_tags[prov->owner]) continue;
		if (!prov->center_of_trade) continue;
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		int need = prov->center_of_trade == "1" ? 10 : 25;
		array desc = ({
			sprintf("%s %04d %s", prov->owner, 9999-dev, prov->name),
			sprintf("%s\tLvl %s\tDev %d\t%s", prov->owner, prov->center_of_trade, dev, string_to_utf8(prov->name)),
		});
		if (prov->center_of_trade == "3") maxlvl += ({desc});
		else if (dev >= need) upgradeable += ({desc});
		else developable += ({desc});
	}
	sort(maxlvl); sort(upgradeable); sort(developable);
	if (sizeof(maxlvl)) write("Max level CoTs:\n%{%s\n%}\n", maxlvl[*][-1]);
	if (sizeof(upgradeable)) write("Upgradeable CoTs:\n\e[1;32m%{%s\n%}\e[0m\n", upgradeable[*][-1]);
	if (sizeof(developable)) write("Developable CoTs:\n\e[1;36m%{%s\n%}\e[0m\n", developable[*][-1]);
}
