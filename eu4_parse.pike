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

void analyze_cot(mapping data, string name, string tag) {
	mapping country = data->countries[tag];
	array maxlvl = ({ }), upgradeable = ({ }), developable = ({ });
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (!prov->center_of_trade) continue;
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		int need = prov->center_of_trade == "1" ? 10 : 25;
		array desc = ({
			sprintf("%s %04d %s", prov->owner, 9999-dev, prov->name),
			prov->center_of_trade,
			sprintf("%s\tLvl %s\tDev %d\t%s", id, prov->center_of_trade, dev, string_to_utf8(prov->name)),
		});
		if (prov->center_of_trade == "3") maxlvl += ({desc});
		else if (dev >= need) upgradeable += ({desc});
		else developable += ({desc});
		//prov->buildings->furnace ?
		//prov->trade_goods == "coal" ?
	}
	sort(maxlvl); sort(upgradeable); sort(developable);
	int level3 = sizeof(country->merchants->envoy); //You can have as many lvl 3 CoTs as you have merchants.
	if (sizeof(maxlvl)) write("Max level CoTs (%d/%d):\n%{%s\n%}\n", sizeof(maxlvl), level3, maxlvl[*][-1]);
	level3 -= sizeof(maxlvl);
	string colorize(string color, array info) {return color * (info[1] != "2" || --level3 > 0) + info[-1];}
	if (sizeof(upgradeable)) write("Upgradeable CoTs:\n%{%s\e[0m\n%}\n", colorize("\e[1;32m", upgradeable[*]));
	if (sizeof(developable)) write("Developable CoTs:\n%{%s\e[0m\n%}\n", colorize("\e[1;36m", developable[*]));
	//$ xdotool search --name "Europa Universalis IV" key --delay 125 f 2 2 4 Return
	//-- bring focus to Sevilla (province 224)
}

constant manufactories = ([
	"farm_estate": "Basic", "mills": "Basic", "plantations": "Basic", "weapons": "Basic",
	"textile": "Basic", "tradecompany": "Basic", "wharf": "Basic",
	"soldier_households": "Special", "impressment_offices": "Special", "state_house": "Special",
]);
void analyze_furnace(mapping data, string name, string tag) {
	mapping country = data->countries[tag];
	array maxlvl = ({ }), upgradeable = ({ }), developable = ({ });
	write("Coal-producing provinces:\n");
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (prov->trade_goods != "coal") continue;
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		mapping bldg = prov->buildings || ([]);
		mapping mfg = bldg & manufactories;
		if (bldg->furnace) write("%s\tHas Furnace\tDev %d\t%s\n", id, dev, string_to_utf8(prov->name));
		else if (prov->building_construction->?building == "32")
			//Currently constructing a Furnace (building type 32 - how do we find out those IDs?)
			write("%s\t%s\tDev %d\t%s\n", id, prov->building_construction->date, dev, string_to_utf8(prov->name));
		else if (sizeof(mfg)) write("\e[1;31m%s\tHas %s\tDev %d\t%s\e[0m\n", id, values(mfg)[0], dev, string_to_utf8(prov->name));
		//Don't know how to count building slots. Would be nice to show "1 free"
		else write("\e[1;32m%s\t%d buildings\tDev %d\t%s\e[0m\n", id, sizeof(bldg), dev, string_to_utf8(prov->name));
	}
	write("\n");
}

void analyze(mapping data, string name, string tag) {
	write("\e[1m== Player: %s (%s) ==\e[0m\n", name, tag);
	({analyze_cot, analyze_furnace})(data, name, tag);
}

int main() {
	string raw = Stdio.read_file("../.local/share/Paradox Interactive/Europa Universalis IV/save games/mp_autosave.eu4"); //Assumes ISO-8859-1, which I think is correct
	mapping data = parse_savefile(raw);
	if (!data) exit(1, "Unable to parse save file (see above for errors, hopefully)\n");
	write("\nCurrent date: %s\n", data->date);
	foreach (data->players_countries / 2, [string name, string tag]) analyze(data, name, tag);
}
