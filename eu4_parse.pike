/*
Read a text EU4 savefile (use mp_autosave.eu4 by default)
Currently scans for upgradeable Centers of Trade and provinces producing Coal.
NOTE: Requires uncompressed non-ironman savefile.
*/

Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("eu4_parse.grammar");

class maparray {
	//Hybrid mapping/array. Can have key-value pairs with string keys, and also an array
	//of values, indexed numerically.
	mapping keyed = ([]);
	array indexed = ({ });
	object addkey(string key, mixed value) {keyed[key] = value; return this;}
	object addidx(mixed value) {indexed += ({value}); return this;}
	protected int _sizeof() {return sizeof(keyed) + sizeof(indexed);}
	protected mixed `[](string|int key) {return intp(key) ? indexed[key] : keyed[key];}
	protected mixed `[]=(string key, mixed val) {return keyed[key] = val;}
	protected mixed `->(string key) {
		switch (key) {
			case "keyed": return keyed;
			case "indexed": return indexed;
			case "addkey": return addkey;
			case "addidx": return addidx;
			default: return keyed[key];
		}
	}
	protected string _sprintf(int type, mapping p) {return sprintf("<%*O/%*O>", p, keyed, p, indexed);}
	//Enable foreach(maparray();int i;mixed val) - but not, unfortunately, foreach(maparray,mixed val)
	protected Array.Iterator _get_iterator() {return get_iterator(indexed);}
}

mixed coalesce(mixed ret_or_brace, mixed ret) {
	if (ret_or_brace != "{") ret = ret_or_brace;
	//Where possible, simplify a maparray down to just a map or an array
	if (!sizeof(ret->indexed)) return ret->keyed;
	if (!sizeof(ret->keyed)) return ret->indexed;
	//Sometimes there's a mapping, but it also has an array of empty mappings after it.
	if (Array.all(ret->indexed, mappingp) && !Array.any(ret->indexed, sizeof)) return ret->keyed;
	return ret;
}
mapping makemapping(mixed name, mixed _, mixed val) {return maparray()->addkey(name, val);}
mapping addmapping(maparray map, mixed name, mixed _, mixed val) {
	//Note that, sometimes, an array is defined by simply assigning multiple times.
	//I have no way of distinguishing an array of one element in that form from a
	//simple entry; and currently, since this is stateless, I can't properly handle
	//an array of arrays.
	if (arrayp(map[name])) map[name] += ({val});
	else if (map[name]) map[name] = ({map[name], val});
	else map[name] = val;
	return map;
}
mapping makearray(mixed val) {return maparray()->addidx(val);}
mapping addarray(maparray arr, mixed val) {return arr->addidx(val);}
mapping emptymaparray() {return ([]);}

mapping low_parse_savefile(string data, int|void verbose) {
	string|array next() {
		sscanf(data, "%[ \t\r\n]%s", string ws, data);
		while (sscanf(data, "#%*s\n%*[ \t\r\n]%s", data)); //Strip comments
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
	return parser->parse(verbose ? shownext : next, this);
}

mapping parse_savefile(string data, int|void verbose) {
	sscanf(Crypto.SHA256.hash(data), "%32c", int hash);
	string hexhash = sprintf("%64x", hash);
	mapping cache = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}");
	if (cache->hash == hexhash) return cache->data;
	if (!sscanf(data, "EU4txt%s", data)) return 0;
	mapping ret = low_parse_savefile(data, verbose);
	Stdio.write_file("eu4_parse.json", string_to_utf8(Standards.JSON.encode((["hash": hexhash, "data": ret]))));
	return ret;
}

mapping prov_area = ([]);
mapping building_slots = ([]);
array(string) interesting_province = ({ });
multiset(string) area_has_level3 = (<>);
void interesting(string id) {if (!has_value(interesting_province, id)) interesting_province += ({id});} //Retain order but avoid duplicates
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
			id,
			sprintf("%s\tLvl %s\tDev %d\t%s", id, prov->center_of_trade, dev, string_to_utf8(prov->name)),
		});
		if (prov->center_of_trade == "3") {maxlvl += ({desc}); area_has_level3[prov_area[id]] = 1;}
		else if (dev >= need) upgradeable += ({desc});
		else developable += ({desc});
	}
	sort(maxlvl); sort(upgradeable); sort(developable);
	int level3 = sizeof(country->merchants->envoy); //You can have as many lvl 3 CoTs as you have merchants.
	if (sizeof(maxlvl)) write("Max level CoTs (%d/%d):\n%{%s\n%}\n", sizeof(maxlvl), level3, maxlvl[*][-1]);
	level3 -= sizeof(maxlvl);
	string colorize(string color, array info) {
		//Colorize if it's interesting. It can't be upgraded if not in a state; also, not all level 2s
		//can become level 3s, for various reasons.
		array have_states = data->map_area_data[prov_area[info[2]]]->?state->?country_state->?country;
		if (!have_states || !has_value(have_states, tag)) return info[-1] + " [is territory]";
		if (info[1] == "2") {
			if (area_has_level3[prov_area[info[2]]]) return info[-1] + " [other l3 in area]";
			if (level3-- <= 0) return info[-1]; //Would put you over your limit (no descriptor here, just lack of colour)
		}
		interesting(info[2]);
		return color + info[-1];
	}
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
	int seen = 0;
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (prov->trade_goods != "coal") continue;
		if (!seen) {write("Coal-producing provinces:\n"); seen = 1;}
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		mapping bldg = prov->buildings || ([]);
		mapping mfg = bldg & manufactories;
		if (bldg->furnace) write("%s\tHas Furnace\tDev %d\t%s\n", id, dev, string_to_utf8(prov->name));
		else if (prov->building_construction->?building == "32")
			//Currently constructing a Furnace (building type 32 - how do we find out those IDs?)
			write("%s\t%s\tDev %d\t%s\n", id, prov->building_construction->date, dev, string_to_utf8(prov->name));
		else if (sizeof(mfg)) write("\e[1;31m%s\tHas %s\tDev %d\t%s\e[0m\n", id, values(mfg)[0], dev, string_to_utf8(prov->name));
		else {
			//Count building slots.
			int slots = 2 + building_slots[id]; //All cities get 2, plus possibly a bonus from terrain and/or a penalty from climate.
			if (bldg->university) ++slots; //A university effectively doesn't consume a slot.
			if (area_has_level3[prov_area[id]]) ++slots; //A level 3 CoT in the state adds a building slot
			//TODO: Modifiers, incl event flags
			slots += dev / 10;
			int buildings = sizeof(bldg);
			if (prov->building_construction) ++buildings;
			interesting(id);
			write("\e[1;%dm%s\t%d/%d bldg\tDev %d\t%s\e[0m\n", buildings < slots ? 32 : 36, id, buildings, slots, dev, string_to_utf8(prov->name));
		}
	}
	if (seen) write("\n");
}

void analyze(mapping data, string name, string tag) {
	interesting_province = ({ }); area_has_level3 = (<>);
	write("\e[1m== Player: %s (%s) ==\e[0m\n", name, tag);
	({analyze_cot, analyze_furnace})(data, name, tag);
	write("* %s * %s\n\n", tag, Standards.JSON.encode((array(int))interesting_province));
}

int main() {
	mapping areas = low_parse_savefile(Stdio.read_file("../.steam/steam/steamapps/common/Europa Universalis IV/map/area.txt"));
	foreach (areas; string areaname; array|maparray provinces)
		foreach (provinces;; string id) prov_area[id] = areaname;
	mapping terrains = low_parse_savefile(Stdio.read_file("../.steam/steam/steamapps/common/Europa Universalis IV/map/terrain.txt"));
	foreach (terrains->categories; string type; mapping info) {
		int slots = (int)info->allowed_num_of_buildings;
		//NOTE: This only catches overrides. It seems that some provinces - maybe a lot of them - aren't
		//listed here, but are somehow assigned to that terrain anyway.
		if (slots) foreach (info->terrain_override, string id) building_slots[id] += slots;
	}
	mapping climates = low_parse_savefile(Stdio.read_file("../.steam/steam/steamapps/common/Europa Universalis IV/map/climate.txt"));
	//For simplicity, I'm not looking up static_modifiers or anything - just arbitrarily flagging Arctic regions.
	foreach (climates->arctic, string id) building_slots[id] -= 1;
	string raw = Stdio.read_file("../.local/share/Paradox Interactive/Europa Universalis IV/save games/mp_autosave.eu4"); //Assumes ISO-8859-1, which I think is correct
	mapping data = parse_savefile(raw);
	if (!data) exit(1, "Unable to parse save file (see above for errors, hopefully)\n");
	write("\nCurrent date: %s\n", data->date);
	foreach (data->players_countries / 2, [string name, string tag]) analyze(data, name, tag);
}
