//Read a text EU4 savefile and scan for matters of interest. Provides info to clients.
//NOTE: Requires non-ironman savefile.
//TODO: Show a coalition as if it's a war?

constant SAVE_PATH = "../.local/share/Paradox Interactive/Europa Universalis IV/save games";
constant PROGRAM_PATH = "../.steam/steam/steamapps/common/Europa Universalis IV"; //Append /map or /common etc to access useful data files

#ifdef QUIET
//Run "pike -DQUIET eu4_parse.pike ...." to avoid warnings from the LR Parser module. Obviously,
//parsing save files won't work in that form.
object parser;
#else
Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("eu4_parse.grammar");
#endif

int retain_map_indices = 0;
class maparray {
	//Hybrid mapping/array. Can have key-value pairs with string keys, and also an array
	//of values, indexed numerically.
	mapping keyed = ([]);
	array indexed = ({ });
	object addkey(string key, mixed value) {
		if (retain_map_indices && mappingp(value)) value |= (["_index": sizeof(keyed)]);
		keyed[key] = value;
		return this;
	}
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

mapping|array|maparray coalesce(mixed ret_or_brace, mixed ret) {
	if (ret_or_brace != "{") ret = ret_or_brace;
	//Where possible, simplify a maparray down to just a map or an array
	if (!sizeof(ret->indexed)) return ret->keyed;
	if (!sizeof(ret->keyed)) return ret->indexed;
	//Sometimes there's a mapping, but it also has an array of empty mappings after it.
	if (Array.all(ret->indexed, mappingp) && !Array.any(ret->indexed, sizeof)) return ret->keyed;
	return ret;
}
maparray makemapping(mixed name, mixed _, mixed val) {return maparray()->addkey(name, val);}
maparray addmapping(maparray map, mixed name, mixed _, mixed val) {
	//Note that, sometimes, an array is defined by simply assigning multiple times.
	//I have no way of distinguishing an array of one element in that form from a
	//simple entry; and currently, since this is stateless, I can't properly handle
	//an array of arrays.
	if (arrayp(map[name])) map[name] += ({val});
	else if (map[name]) map[name] = ({map[name], val});
	else map->addkey(name, val);
	return map;
}
maparray makearray(mixed val) {return maparray()->addidx(val);}
maparray addarray(maparray arr, mixed val) {return arr->addidx(val);}
mapping emptymaparray() {return ([]);}

mapping low_parse_savefile(string|Stdio.Buffer data, int|void verbose) {
	if (stringp(data)) data = Stdio.Buffer(data); //NOTE: Restricted to eight-bit data. Since EU4 uses ISO-8859-1, that's not a problem. Be aware for future.
	data->read_only();
	string ungetch;
	string|array next() {
		if (string ret = ungetch) {ungetch = 0; return ret;}
		data->sscanf("%*[ \t\r\n]");
		while (data->sscanf( "#%*s\n%*[ \t\r\n]")); //Strip comments
		if (!sizeof(data)) return "";
		if (array str = data->sscanf("\"%[^\"]\"")) {
			//How are embedded quotes and/or backslashes handled?
			return ({"string", str[0]});
		}
		if (array digits = data->sscanf("%[-0-9.]")) return ({"string", digits[0]});
		if (array|string word = data->sscanf("%[0-9a-zA-Z_]")) {
			word = word[0];
			if ((<"yes", "no">)[word]) return ({"boolean", word == "yes"});
			//Hack: this one element seems to omit the equals sign for some reason.
			if (word == "map_area_data") ungetch = "=";
			return ({"string", word});
		}
		return data->read(1);
	}
	string|array shownext() {mixed tok = next(); write("%O\n", tok); return tok;}
	//while (shownext() != ""); return 0; //Dump tokens w/o parsing
	return parser->parse(verbose ? shownext : next, this);
}

//File-like object that reads from a string. Potentially does a lot of string copying.
class StringFile(string basis) {
	int pos = 0;
	int seek(int offset, string|void whence) {
		switch (whence) {
			case Stdio.SEEK_SET: pos = offset; break;
			case Stdio.SEEK_CUR: pos += offset; break;
			case Stdio.SEEK_END: pos = sizeof(basis) + offset; break;
			case 0: pos = offset + sizeof(basis) * (offset < 0); break; //Default is SEEK_END if negative, else SEEK_SET
		}
		return pos;
	}
	int tell() {return pos;}
	string(8bit) read(int len) {
		string ret = basis[pos..pos+len-1];
		pos += len;
		return ret;
	}
	void stat() { } //No file system stats available.
}

mapping parse_savefile_string(string data, int|void verbose) {
	if (has_prefix(data, "PK\3\4")) {
		//Compressed savefile. Consists of three files, one of which ("ai") we don't care
		//about. The other two can be concatenated after stripping their "EU4txt" headers,
		//and should be able to be parsed just like an uncompressed save. (The ai file is
		//also the exact same format, so if it's ever needed, just add a third sscanf.)
		object zip = Filesystem.Zip._Zip(StringFile(data));
		sscanf(zip->read("meta") || "", "EU4txt%s", string meta);
		sscanf(zip->read("gamestate") || "", "EU4txt%s", string state);
		if (meta && state) data = meta + state; else return 0;
	}
	else if (!sscanf(data, "EU4txt%s", data)) return 0;
	if (verbose) write("Parsing %d bytes...\n", sizeof(data));
	return low_parse_savefile(data, verbose);
}

mapping parse_savefile(string data, int|void verbose) {
	sscanf(Crypto.SHA256.hash(data), "%32c", int hash);
	string hexhash = sprintf("%64x", hash);
	mapping cache = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}");
	if (cache->hash == hexhash) return cache->data;
	mapping ret = parse_savefile_string(data, verbose);
	Stdio.write_file("eu4_parse.json", string_to_utf8(Standards.JSON.encode((["hash": hexhash, "data": ret]))));
	return ret;
}

mapping(string:string) L10n;
void parse_localisation(string data) {
	data = utf8_to_string(data);
	sscanf(data, "%*s\n%{ %s:%*d \"%s\"\n%}", array info);
	L10n |= (mapping)info;
}

string tabulate(array(string) headings, array(array(mixed)) data, string|void gutter, int|void summary) {
	if (!gutter) gutter = " ";
	array info = ({headings}) + (array(array(string)))data;
	array(int) widths = map(Array.transpose(info)) {return max(@sizeof(__ARGS__[0][*]));};
	//Hack: First column isn't size-counted or guttered. It's for colour codes and such.
	string fmt = sprintf("%%%ds", widths[1..][*]) * gutter;
	//If there's a summary row, insert a ruler before it. (You can actually have multiple summary rows if you like.)
	if (summary) info = info[..<summary] + ({({headings[0]}) + "\u2500" * widths[1..][*]}) + info[<summary-1..];
	return sprintf("%{%s" + fmt + "\e[0m\n%}", info);
}

int threeplace(string value) {
	//EU4 uses three-place fixed-point for a lot of things. Return the number as an integer,
	//ie "3.142" is returned as 3142.
	if (!value) return 0;
	sscanf(value, "%d.%s", int whole, string frac);
	return whole * 1000 + (int)sprintf("%.03s", frac);
}

mapping prov_area = ([]);
mapping province_info;
mapping building_types; array building_id;
mapping building_slots = ([]);
array(string) interesting_province = ({ });
multiset(string) area_has_level3 = (<>);
void interesting(string id) {if (!has_value(interesting_province, id)) interesting_province += ({id});} //Retain order but avoid duplicates
void analyze_cot(mapping data, string name, string tag, function write) {
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
	else write("Max level CoTs: 0/%d\n", level3);
	level3 -= sizeof(maxlvl);
	string colorize(string color, array info) {
		//Colorize if it's interesting. It can't be upgraded if not in a state; also, not all level 2s
		//can become level 3s, for various reasons.
		array have_states = data->map_area_data[prov_area[info[2]]]->?state->?country_state->?country;
		if (!have_states || !has_value(have_states, tag)) return info[-1] + " [is territory]";
		if (info[1] == "2") {
			if (area_has_level3[prov_area[info[2]]]) return info[-1] + " [other l3 in area]";
			if (level3-- <= 0) return info[-1] + " [need merchants]";
		}
		interesting(info[2]);
		return color + info[-1];
	}
	if (sizeof(upgradeable)) write("Upgradeable CoTs:\n%{%s\e[0m\n%}\n", colorize("\e[1;32m", upgradeable[*]));
	if (sizeof(developable)) write("Developable CoTs:\n%{%s\e[0m\n%}\n", colorize("\e[1;36m", developable[*]));
}

object calendar(string date) {
	sscanf(date, "%d.%d.%d", int year, int mon, int day);
	return Calendar.Gregorian.Day(year, mon, day);
}

void analyze_leviathans(mapping data, string name, string tag, function write) {
	if (!has_value(data->dlc_enabled, "Leviathan")) return;
	mapping country = data->countries[tag];
	array projects = ({ });
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (!prov->great_projects) continue;
		mapping con = prov->great_project_construction || ([]);
		foreach (prov->great_projects, string project) {
			mapping proj = data->great_projects[project];
			projects += ({({
				(int)id - (int)proj->development_tier * 10000,
				({"", id, "Lvl " + proj->development_tier, prov->name, L10n[project],
					//It's possible that con->type is "1" for upgrades and "2" for moving it to your capital
					con->great_projects == project ? sprintf("%d%%, due %s", threeplace(con->progress) / 10, con->date) : "",
				}),
			})});
			//write("Project: %O\n", proj);
		}
		//if (con) write("Construction: %O\n", con);
	}
	sort(projects);
	if (sizeof(projects)) write("%s\n", string_to_utf8(tabulate(({""}) + "ID Tier Province Project Upgrading" / " ", projects[*][-1], "  ", 0)));
	write("\nFavor cooldowns:\n");
	object today = calendar(data->date);
	array cooldowns = ({ });
	foreach ("gold men sailors" / " ", string tradefor) {
		string date = country->cooldowns["trade_favors_for_" + tradefor];
		if (!date) {cooldowns += ({({"", "---", "--------", String.capitalize(tradefor)})}); continue;}
		int days = today->distance(calendar(date)) / today;
		cooldowns += ({({"", days, date, String.capitalize(tradefor)})});
	}
	write("%s\n", string_to_utf8(tabulate(({"", "Days", "Date", "Trade for"}), cooldowns, "  ", 0)));
}

int count_building_slots(mapping data, string id) {
	//Count building slots. Not perfect. Depends on the CoTs being provided accurately.
	//Doesn't always give the terrain bonus.
	int slots = 2 + building_slots[id]; //All cities get 2, plus possibly a bonus from terrain and/or a penalty from climate.
	mapping prov = data->provinces["-" + id];
	if (prov->buildings->?university) ++slots; //A university effectively doesn't consume a slot.
	if (area_has_level3[prov_area[id]]) ++slots; //A level 3 CoT in the state adds a building slot
	//TODO: Modifiers, incl event flags
	int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
	return slots + dev / 10;
}

mapping(string:string) manufactories = ([]); //Calculated from building_types
void analyze_furnace(mapping data, string name, string tag, function write) {
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
		else if (building_id[(int)prov->building_construction->?building] == "furnace")
			write("%s\t%s\tDev %d\t%s\n", id, prov->building_construction->date, dev, string_to_utf8(prov->name));
		else if (sizeof(mfg)) write("\e[1;31m%s\tHas %s\tDev %d\t%s\e[0m\n", id, values(mfg)[0], dev, string_to_utf8(prov->name));
		else {
			int slots = count_building_slots(data, id);
			int buildings = sizeof(bldg);
			if (prov->building_construction) ++buildings;
			interesting(id);
			write("\e[1;%dm%s\t%d/%d bldg\tDev %d\t%s%s\e[0m\n", buildings < slots ? 32 : 36, id, buildings, slots, dev,
				string_to_utf8(prov->name), prov->settlement_growth_construction ? " - SETTLER ACTIVE" : ""); //Can't build while there's a settler promoting growth);
		}
	}
	if (seen) write("\n");
}

void analyze_upgrades(mapping data, string name, string tag, function write) {
	mapping country = data->countries[tag];
	mapping upgradeables = ([]);
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (!prov->buildings) continue;
		string constructing = building_id[(int)prov->building_construction->?building]; //0 if not constructing anything
		foreach (prov->buildings; string b;) {
			mapping bldg = building_types[b]; if (!bldg) continue; //Unknown building??
			if (bldg->influencing_fort) continue; //Ignore forts - it's often not worth upgrading all forts. (TODO: Have a way to request forts too.)
			mapping target;
			while (mapping upgrade = building_types[bldg->obsoleted_by]) {
				[string techtype, int techlevel] = upgrade->tech_required;
				if ((int)country->technology[techtype] < techlevel) break;
				//Okay. It can be upgraded. But before we report it, see if we can go another level.
				//For instance, if you have a Marketplace and Diplo tech 22, you can upgrade to a
				//Trade Depot, but could go straight to Stock Exchange.
				target = bldg->obsoleted_by;
				bldg = upgrade;
			}
			if (target && target != constructing) {interesting(id); upgradeables[target] += ({prov->name});}
		}
	}
	foreach (sort(indices(upgradeables)), string b) {
		write("Can upgrade %d buildings to %s\n", sizeof(upgradeables[b]), b);
		write("==> %s\n", string_to_utf8(upgradeables[b] * ", "));
	}
}

void analyze_findbuildings(mapping data, string name, string tag, function write, string highlight) {
	mapping country = data->countries[tag];
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		//Building shipyards in inland provinces isn't very productive
		if (building_types[highlight]->build_trigger->?has_port && !province_info[id]->?has_port) continue;
		mapping bldg = prov->buildings || ([]);
		int slots = count_building_slots(data, id);
		int buildings = sizeof(bldg);
		if (prov->building_construction) ++buildings;
		if (buildings < slots) continue; //Got room. Not a problem. (Note that the building slots calculation may be wrong but usually too low.)
		//Check if a building of the highlight type already exists here.
		int gotone = 0;
		foreach (prov->buildings; string b;) {
			while (string upg = building_types[b]->make_obsolete) b = upg;
			if (b == highlight) {gotone = 1; break;}
		}
		if (gotone) continue;
		interesting(id);
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		write("\e[1;32m%s\t%d/%d bldg\tDev %d\t%s\e[0m\n", id, buildings, slots, dev, string_to_utf8(prov->name));
	}
}

mapping(string:array) interesting_provinces = ([]);
void analyze(mapping data, string name, string tag, function|void write, string|void highlight) {
	if (!write) write = Stdio.stdin->write;
	interesting_province = ({ }); area_has_level3 = (<>);
	write("\e[1m== Player: %s (%s) ==\e[0m\n", name, tag);
	({analyze_cot, analyze_leviathans, analyze_furnace, analyze_upgrades})(data, name, tag, write);
	if (highlight) analyze_findbuildings(data, name, tag, write, highlight);
	//write("* %s * %s\n\n", tag, Standards.JSON.encode((array(int))interesting_province)); //If needed in a machine-readable format
	interesting_provinces[tag] = interesting_province;
}

void analyze_flagships(mapping data, function|void write) {
	if (!write) write = Stdio.stdin->write; //Wait. How does this even work?? FIXME - shouldn't it fail, and make me use stdout properly?!?
	array flagships = ({ });
	foreach (data->countries; string tag; mapping country) {
		//mapping country = data->countries[tag];
		if (!country->navy) continue;
		foreach (Array.arrayify(country->navy), mapping fleet) {
			foreach (Array.arrayify(fleet->ship), mapping ship) {
				if (!ship->flagship) continue;
				string cap = "";
				if (ship->flagship->is_captured) {
					string was = ship->flagship->original_owner;
					cap = " CAPTURED from " + (data->countries[was]->name || L10n[was] || was);
				}
				flagships += ({({
					string_to_utf8(sprintf("\e[1m%s\e[0m - %s: \e[36m%s %q\e[31m%s\e[0m",
						country->name || L10n[tag] || tag, fleet->name,
						String.capitalize(ship->type), ship->name, cap)),
					//Measure size without colour codes or UTF-8 encoding
					sizeof(sprintf("%s - %s: %s %q%s",
						country->name || L10n[tag] || tag, fleet->name,
						String.capitalize(ship->type), ship->name, cap)),
					ship->flagship->modification * ", ",
				})});
				//write("%O\n", ship->flagship);
			}
		}
	}
	if (!sizeof(flagships)) return;
	write("\n\e[1m== Flagships of the World ==\e[0m\n");
	sort(flagships);
	int width = max(@flagships[*][1]);
	foreach (flagships, array f) f[1] = " " * (width - f[1]);
	write("%{%s %s %s\n%}", flagships);
}

mapping transform(string ... types) {
	mapping ret = ([]);
	foreach (types, string type) {
		sscanf(type, "%s: %{%s %}", string value, array keys);
		foreach (keys, [string key]) ret[key] = value;
	}
	return ret;
}
mapping ship_types = transform(
	"heavy_ship: early_carrack carrack galleon wargalleon twodecker threedecker",
	"light_ship: barque caravel early_frigate frigate heavy_frigate great_frigate",
	"galley: galley war_galley galleass galiot chebeck archipelago_frigate",
	"transport: war_canoe cog flute brig merchantman trabakul eastindiaman",
);

void analyze_wars(mapping data, multiset(string) tags, function|void write) {
	if (!write) write = Stdio.stdin->write;
	foreach (data->active_war || ({ }), mapping war) {
		//To keep displaying the war after all players separate-peace out, use
		//war->persistent_attackers and war->persistent_defenders instead.
		int is_attacker = war->attackers && sizeof((multiset)war->attackers & tags);
		int is_defender = war->defenders && sizeof((multiset)war->defenders & tags);
		if (!is_attacker && !is_defender) continue; //Irrelevant bickering somewhere in the world.
		//If there are players on both sides of the war, show "attackers" and "defenders".
		//But if all players are on one side of a war, show "allies" and "enemies".
		string atk = "\U0001f5e1\ufe0f", def = "\U0001f6e1\ufe0f";
		int defender = is_defender && !is_attacker;
		if (defender) [atk, def] = ({def, atk});
		write("\n\e[1;31m== War: %s - %s ==\e[0m\n", war->action, string_to_utf8(war->name));
		//war->action is the date it started?? Maybe the last date when a call to arms is valid?
		//war->called - it's all just numbers, no country tags. No idea.

		//Ticking war score is either war->defender_score or war->attacker_score and is a positive number.
		float ticking_ws = (float)(war->attacker_score || "-" + war->defender_score);
		if (defender) ticking_ws = -ticking_ws;
		//Overall war score?? Can't figure that out. It might be that it isn't stored.

		//war->participants[*]->value is the individual contribution. To turn this into a percentage,
		//be sure to sum only the values on one side, as participants[] has both sides of the war in it.
		array armies = ({ }), navies = ({ });
		array(array(int)) army_total = ({allocate(8), allocate(8)});
		array(array(int)) navy_total = ({allocate(6), allocate(6)});
		foreach (war->participants, mapping p) {
			mapping country = data->countries[p->tag];
			int a = has_value(war->attackers, p->tag), d = has_value(war->defenders, p->tag);
			if (!a && !d) continue; //War participant has subsequently peaced out
			string side = sprintf("\e[48;2;%d;%d;%dm%s  ",
				a && 30, //Red for attacker
				tags[p->tag] && 60, //Cyan or olive for player
				d && 30,
				a ? atk : def, //Sword or shield
			);
			//I don't know how to recognize that eastern_militia is infantry and muscovite_cossack is cavalry.
			//For land units, we can probably assume that you use only your current set. For sea units, there
			//aren't too many (and they're shared by all nations), so I just hard-code them.
			mapping unit_types = mkmapping(values(country->sub_unit), indices(country->sub_unit));
			mapping mil = ([]), mercs = ([]);
			if (country->army) foreach (Array.arrayify(country->army), mapping army) {
				string merc = army->mercenary_company ? "merc_" : "";
				foreach (Array.arrayify(army->regiment), mapping reg) {
					//Note that regiment strength is eg "0.807" for 807 men. We want the
					//number of men, so there's no need to re-divide.
					mil[merc + unit_types[reg->type]] += reg->strength ? threeplace(reg->strength) : 1000;
				}
			}
			if (country->navy) foreach (Array.arrayify(country->navy), mapping navy) {
				foreach (Array.arrayify(navy->ship), mapping ship) {
					mil[ship_types[ship->type]] += 1; //Currently not concerned about hull strength. You either have or don't have a ship.
				}
			}
			int mp = threeplace(country->manpower);
			int total_army = mil->infantry + mil->cavalry + mil->artillery + mil->merc_infantry + mil->merc_cavalry + mil->merc_artillery;
			armies += ({({
				-total_army * 1000000000 - mp,
				({
					side,
					country->name || L10n[p->tag] || p->tag,
					mil->infantry, mil->cavalry, mil->artillery,
					mil->merc_infantry, mil->merc_cavalry, mil->merc_artillery,
					total_army, mp,
					sprintf("%3.0f%%", (float)country->army_professionalism * 100.0),
					sprintf("%3.0f%%", (float)country->army_tradition),
				}),
			})});
			army_total[d] = army_total[d][*] + armies[-1][1][2..<2][*];
			int sailors = (int)country->sailors; //Might be 0, otherwise is eg "991.795" (we don't care about the fraction, this means 991 sailors)
			int total_navy = mil->heavy_ship + mil->light_ship + mil->galley + mil->transport;
			navies += ({({
				-total_navy * 1000000000 - sailors,
				({
					side,
					country->name || L10n[p->tag] || p->tag,
					mil->heavy_ship, mil->light_ship, mil->galley, mil->transport, total_navy, sailors,
					sprintf("%3.0f%%", (float)country->navy_tradition),
				}),
			})});
			navy_total[d] = navy_total[d][*] + navies[-1][1][2..<1][*];
		}
		armies += ({
			//The totals get sorted after the individual country entries. Their sort keys are
			//guaranteed positive, and are such that the larger army has a smaller sort key.
			//Easiest way to do that is to swap them :)
			({1 + army_total[1][-2] + army_total[1][-1], ({"\e[48;2;50;0;0m" + atk + "  ", ""}) + army_total[0] + ({"", ""})}),
			({1 + army_total[0][-2] + army_total[0][-1], ({"\e[48;2;0;0;50m" + def + "  ", ""}) + army_total[1] + ({"", ""})}),
		});
		navies += ({
			({1 + navy_total[1][-2] + navy_total[1][-1], ({"\e[48;2;50;0;0m" + atk + "  ", ""}) + navy_total[0] + ({""})}),
			({1 + navy_total[0][-2] + navy_total[0][-1], ({"\e[48;2;0;0;50m" + def + "  ", ""}) + navy_total[1] + ({""})}),
		});
		sort(armies); sort(navies);
		write("%s\n", string_to_utf8(tabulate(({"   "}) + "Country Infantry Cavalry Artillery Inf$$ Cav$$ Art$$ Total Manpower Prof Trad" / " ", armies[*][-1], "  ", 2)));
		write("%s\n", string_to_utf8(tabulate(({"   "}) + "Country Heavy Light Galley Transp Total Sailors Trad" / " ", navies[*][-1], "  ", 2)));
	}
}

multiset(object) connections = (<>);
mapping last_parsed_savefile;
class Connection(Stdio.File sock) {
	Stdio.Buffer incoming = Stdio.Buffer(), outgoing = Stdio.Buffer();
	string notify, highlight;

	protected void create() {
		//write("%%%% Connection from %s\n", sock->query_address());
		sock->set_buffer_mode(incoming, outgoing);
		sock->set_nonblocking(sockread, 0, sockclosed);
	}
	void sockclosed() {connections[this] = 0; sock->close();}

	string find_country(mapping data, string country) {
		foreach (data->players_countries / 2, [string name, string tag])
			if (lower_case(country) == lower_case(name)) country = tag;
		if (data->countries[country]) return country;
		outgoing->sprintf("Player or tag %O not found - try%{ %O%} or any country tag\n", country, data->players_countries);
		sock->write(""); //Force a write callback (shouldn't be necessary??)
	}

	void inform(mapping data) {
		//A savefile has been parsed. Notify this socket (if applicable).
		if (!notify) return;
		string tag = find_country(data, notify); if (!tag) return;
		analyze(data, notify, tag, outgoing->sprintf, highlight);
		analyze_wars(data, (<tag>), outgoing->sprintf);
		sock->write(""); //Ditto
	}

	void cycle_provinces(string country) {
		if (!last_parsed_savefile) return;
		string tag = find_country(last_parsed_savefile, country); if (!tag) return;
		if (!interesting_provinces[tag]) analyze(last_parsed_savefile, "Province finder", tag); //Should this be sent to /dev/null instead of the console?
		if (!sizeof(interesting_provinces[tag])) {sock->close("w"); return;}
		[string id, array rest] = Array.shift(interesting_provinces[tag]);
		interesting_provinces[tag] = rest + ({id});
		//Note: Ignores buffered mode and writes directly. I don't think it's possible to
		//put a "shutdown write direction when done" marker into the Buffer.
		sock->write(id + "\n");
		sock->close("w");
	}

	void sockread() {
		while (array ret = incoming->sscanf("%s\n")) {
			string cmd = String.trim(ret[0]), arg = "";
			sscanf(cmd, "%s %s", cmd, arg);
			switch (cmd) {
				case "notify":
					notify = arg; connections[this] = 1;
					if (last_parsed_savefile) inform(last_parsed_savefile);
					break;
				case "province": cycle_provinces(arg); break;
				case "highlight": case "hl": case "build": case "building": case "buildings": {
					//Request highlighting of provinces in which a particular building could be built if you had a slot.
					//Example: "highlight shipyard" ==> any province with no shipyard and no building slots gets highlighted.
					//Typing "highlight" without an arg, or any invalid arg, will give a list of building IDs.
					arg = replace(lower_case(arg), " ", "_");
					if ((<"none", "off", "-">)[arg]) {
						highlight = 0;
						outgoing->sprintf("Highlighting disabled.\n");
						sock->write("");
						break;
					}
					string tag = last_parsed_savefile && find_country(last_parsed_savefile, notify);
					if (!tag) break;
					if (!building_types[arg]) {
						array available = ({ });
						mapping tech = last_parsed_savefile->countries[tag]->technology;
						int have_mfg = 0;
						foreach (building_types; string id; mapping bldg) {
							[string techtype, int techlevel] = bldg->tech_required || ({"", 100}); //Ignore anything that's not a regular building
							if ((int)tech[techtype] < techlevel) continue; //Hide IDs you don't have the tech to build
							if (bldg->obsoleted_by) continue; //Show only the baseline building for each type
							if (bldg->manufactory && !bldg->show_separate) {have_mfg = 1; continue;} //Collect regular manufactories under one name
							if (bldg->influencing_fort) continue; //You won't want to check forts this way
							available += ({id});
						}
						if (have_mfg) available += ({"manufactory"}); //Note that building_types->manufactory is technically valid
						outgoing->sprintf("Valid IDs: %s\n", sort(available) * ", ");
						outgoing->sprintf("Or use 'highlight none' to disable.\n");
						sock->write("");
						break;
					}
					//If you say "highlight stock_exchange", act as if you said "highlight marketplace".
					while (string older = building_types[arg]->make_obsolete) arg = older;
					highlight = arg;
					analyze_findbuildings(last_parsed_savefile, notify, tag, outgoing->sprintf, arg);
					sock->write("");
					break;
				}
				case "flagship": case "flagships": case "flag": case "fs":
					analyze_flagships(last_parsed_savefile, outgoing->sprintf);
					sock->write("");
					break;
				case "war": case "wars": {
					if (arg == "") {
						foreach (last_parsed_savefile->active_war || ({ }), mapping war) {
							outgoing->sprintf("\n\e[1;31m== War: %s - %s ==\e[0m\n", war->action, string_to_utf8(war->name));
							if (war->attackers) outgoing->sprintf(string_to_utf8("\U0001f5e1\ufe0f %{ %s%}\n"), war->attackers);
							if (war->defenders) outgoing->sprintf(string_to_utf8("\U0001f6e1\ufe0f %{ %s%}\n"), war->defenders);
						}
						sock->write("");
						break;
					}
					string tag = find_country(last_parsed_savefile, arg); if (!tag) break;
					analyze_wars(last_parsed_savefile, (<tag>), outgoing->sprintf);
					sock->write("");
					break;
				}
				default: sock->write(sprintf("Unknown command %O\n", cmd)); break;
			}
		}
	}
}

void sock_connected(object mainsock) {while (object sock = mainsock->accept()) Connection(sock);}

Stdio.File parser_pipe = Stdio.File();
void process_savefile(string fn) {parser_pipe->write(fn + "\n");}
void done_processing_savefile() {
	parser_pipe->read();
	mapping data = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}")->data;
	if (!data) {werror("Unable to parse save file (see above for errors, hopefully)\n"); return;}
	write("\nCurrent date: %s\n", data->date);
	foreach (data->players_countries / 2, [string name, string tag]) analyze(data, name, tag);
	analyze_flagships(data);
	analyze_wars(data, (multiset)(data->players_countries / 2)[*][1]);
	indices(connections)->inform(data);
	last_parsed_savefile = data;
}

class ClientConnection {
	inherit Connection;
	protected void create(Stdio.File sock) {
		::create(sock);
		Stdio.stdin->set_read_callback(stdinread);
		Stdio.stdin->set_close_callback(stdineof);
	}
	void sockread() {
		//Display only complete lines, to avoid disruption of input text
		while (array ret = incoming->sscanf("%s\n")) write("%s\n", ret[0]);
	}
	void sockclosed() {::sockclosed(); exit(0);}
	void stdinread(mixed _, string data) {sock->write(data);}
	void stdineof() {sock->close("w");}
}

class PipeConnection {
	inherit Connection;
	void sockread() {
		while (array ret = incoming->sscanf("%s\n")) {
			[string fn] = ret;
			write("Reading save file %s\n", basename(fn));
			string raw = Stdio.read_file(fn); //Assumes ISO-8859-1, which I think is correct
			parse_savefile(raw);
			sock->write("*"); //Signal the parent. It can read it back from the cache.
		}
	}
}

int main(int argc, array(string) argv) {
	if (argc > 1 && argv[1] == "--parse") {
		//Parser subprocess, invoked by parent for asynchronous parsing.
		PipeConnection(Stdio.File(3)); //We should have been given fd 3 as a pipe
		return -1;
	}
	if (argc > 1 && argv[1] == "--timeparse") {
		object start = System.Timer();
		#define TIME(x) {float tm = gauge {x;}; write("%.3f\t%.3f\t%s\n", start->get(), tm, #x);}
		string raw; TIME(raw = Stdio.read_file(SAVE_PATH + "/mp_autosave.eu4"));
		mapping data; TIME(data = parse_savefile_string(raw));
		write("Parse successful. Date: %s\n", data->date);
		return 0;
	}
	if (argc > 2) {
		//First arg is server name/IP; the rest are joined and sent as a command.
		//If the second arg is "province", then the result is fed as keys to EU4.
		//Otherwise, this is basically like netcat/telnet.
		Stdio.File sock = Stdio.File();
		string writeme = sock->connect(argv[1], 1444, argv[2..] * " " + "\n");
		if (!writeme) exit(0, "Unable to connect to %s : 1444\n", argv[1]);
		sock->write(writeme); //TBH there shouldn't be any residual data, since it should be a single packet.
		if (argv[2] != "province") {ClientConnection(sock); return -1;}
		string province = "";
		while (string data = sock->read(1024, 1)) {
			if (data == "") break;
			province += data;
		}
		sock->close();
		if (String.trim(province) != "") Process.create_process(({"xdotool",
			/*"search", "--name", "Europa Universalis IV",*/ //Doesn't always work. Omitting this assumes that EU4 has focus.
			"key", "--delay", "125", //Hurry the typing along a bit
			"f", @(String.trim(province) / ""), "Return", //Send "f", then type the province ID, then hit Enter
		}))->wait();
		return 0;
	}

	//Load up some info that is presumed to not change. If you're modding the game, this may break.
	catch {L10n = Standards.JSON.decode_utf8(Stdio.read_file(".eu4_localisation.json"));};
	if (!mappingp(L10n)) {
		L10n = ([]);
		foreach (glob("*_l_english.yml", get_dir(PROGRAM_PATH + "/localisation")), string fn)
			parse_localisation(Stdio.read_file(PROGRAM_PATH + "/localisation/" + fn));
		Stdio.write_file(".eu4_localisation.json", Standards.JSON.encode(L10n, 1));
	}
	mapping areas = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/map/area.txt"));
	foreach (areas; string areaname; array|maparray provinces)
		foreach (provinces;; string id) prov_area[id] = areaname;
	mapping terrains = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/map/terrain.txt"));
	//Terrain info is used below.
	mapping climates = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/map/climate.txt"));
	//For simplicity, I'm not looking up static_modifiers or anything - just arbitrarily flagging Arctic regions.
	foreach (climates->arctic, string id) building_slots[id] -= 1;
	retain_map_indices = 1;
	building_types = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/buildings/00_buildings.txt"));
	retain_map_indices = 0;
	building_id = allocate(sizeof(building_types));
	foreach (building_types; string id; mapping info) {
		if (info->manufactory) manufactories[id] = info->show_separate ? "Special" : "Basic";
		//Map the index to the ID, counting from 1, but skipping the "manufactory" pseudo-entry
		//(not counting it and collapsing the gap).
		if (id != "manufactory") building_id[info->_index + (info->_index < building_types->manufactory->_index)] = id;
	}
	foreach (({"adm", "dip", "mil"}), string cat) {
		mapping tech = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/technologies/" + cat + ".txt"));
		foreach (tech->technology; int level; mapping effects) {
			//The effects include names of buildings, eg "university = yes".
			foreach (effects; string id;) if (mapping bld = building_types[id]) {
				bld->tech_required = ({cat + "_tech", level});
				if (bld->make_obsolete) building_types[bld->make_obsolete]->obsoleted_by = id;
			}
		}
	}

	/* It is REALLY REALLY hard to replicate the game's full algorithm for figuring out which terrain each province
	has. So, instead, let's ask for a little help - from the game, and from the human. And then save the results.
	Unfortunately, it's not possible (as of v1.31) to do an every_province scope that reports the province ID in a
	log message. It also doesn't seem to be possible to iterate over all provinces and increment a counter, as the
	every_province scope skips sea provinces (which still consume province IDs).
	I would REALLY like to do something like this:
	every_province = {
		limit = {
			has_terrain = steppe
			is_wasteland = no
		}
		log = "PROV-TERRAIN: steppe [This.ID] [This.GetName]"
	}
	
	and repeat for each terrain type. A technique others have done is to cede the provinces to different countries,
	save, and parse the savefile; this is slow, messy, and mutates the save, so it won't be very useful in Random
	New World. (Not that I'm going to try to support RNW, but it should be easier this way if I do in the future.)

	Since we can't do it the easy way, let's do it the hard way instead. For each province ID, for each terrain, if
	the province has that terrain, log a message. If it's stupid, but it works........ no, it's still stupid.
	*/
	province_info = Standards.JSON.decode(Stdio.read_file(".eu4_provinces.json") || "0");
	if (!mappingp(province_info)) {
		//Build up a script file to get the info we need.
		//We assume that every province that could be of interest to us will be in an area.
		Stdio.File script = Stdio.File(SAVE_PATH + "/../prov.txt", "wct");
		script->write("log = \"PROV-TERRAIN-BEGIN\"\n");
		foreach (sort(indices(prov_area)), string provid) {
			script->write(
#"%s = {
	set_variable = { which = terrain_reported value = -1 }
	if = {
		limit = { has_port = yes is_wasteland = no }
		log = \"PROV-TERRAIN: %<s has_port=1\"
	}
", provid);
			foreach (terrains->categories; string type; mapping info) {
				script->write(
#"	if = {
		limit = { has_terrain = %s is_wasteland = no }
		log = \"PROV-TERRAIN: %s terrain=%[0]s\"
	}
", type, provid);
			}
			script->write("}\n");
		}
		//For reasons of paranoia, iterate over all provinces and make sure we reported their
		//terrain types.
		script->write(#"
every_province = {
	limit = { check_variable = { which = terrain_reported value = 0 } is_wasteland = no }
	log = \"PROV-TERRAIN-ERROR: Terrain not reported for province [This.GetName]\"
}
log = \"PROV-TERRAIN-END\"
");
		script->close();
		//See if the script's already been run (yes, we rebuild the script every time - means you
		//can rerun it in case there've been changes), and if so, parse and save the data.
		string log = Stdio.read_file(SAVE_PATH + "/../logs/game.log") || "";
		if (!has_value(log, "PROV-TERRAIN-BEGIN") || !has_value(log, "PROV-TERRAIN-END"))
			exit(0, "Please open up EU4 and, in the console, type: run prov.txt\n");
		string terrain = ((log / "PROV-TERRAIN-BEGIN")[-1] / "PROV-TERRAIN-END")[0];
		province_info = ([]);
		foreach (terrain / "\n", string line) {
			//Lines look like this:
			//[effectimplementation.cpp:21960]: EVENT [1444.11.11]:PROV-TERRAIN: drylands 224 - Sevilla
			sscanf(line, "%*sPROV-TERRAIN: %d %s=%s", int provid, string key, string val);
			if (!provid) continue;
			mapping pt = province_info[(string)provid] || ([]); province_info[(string)provid] = pt;
			pt[key] = String.trim(val);
		}
		Stdio.write_file(".eu4_provinces.json", Standards.JSON.encode(province_info));
	}
	foreach (province_info; string id; mapping provinfo) {
		mapping terraininfo = terrains->categories[provinfo->terrain];
		if (!terraininfo) continue; //TODO: What happens if we have a broken terrain name??
		int slots = (int)terraininfo->allowed_num_of_buildings;
		if (slots) building_slots[id] += slots;
	}

	object proc = Process.spawn_pike(({argv[0], "--parse"}), (["fds": ({parser_pipe->pipe(Stdio.PROP_NONBLOCK|Stdio.PROP_BIDIRECTIONAL|Stdio.PROP_IPC)})]));
	parser_pipe->set_nonblocking(done_processing_savefile, 0, parser_pipe->close);
	//Find the newest .eu4 file in the directory and (re)parse it, then watch for new files.
	array(string) files = SAVE_PATH + "/" + get_dir(SAVE_PATH)[*];
	sort(file_stat(files[*])->mtime, files);
	if (sizeof(files)) process_savefile(files[-1]);
	object inot = System.Inotify.Instance();
	string new_file; int nomnomcookie;
	inot->add_watch(SAVE_PATH, System.Inotify.IN_CLOSE_WRITE | System.Inotify.IN_MOVED_TO | System.Inotify.IN_MOVED_FROM) {
		[int event, int cookie, string path] = __ARGS__;
		//EU4 seems to always save into a temporary file, then rename it over the target. This
		//sometimes includes renaming the target out of the way first (eg old_autosave.eu4).
		//There are a few ways to detect new save files.
		//1) Watch for a CLOSE_WRITE event, which will be the temporary file (eg autosave.tmp).
		//   When you see that, watch for the next MOVED_FROM event for that same name, and then
		//   the corresponding MOVED_TO event is the target name. Assumes that the file is created
		//   in the savegames directory and only renamed, never moved in.
		//2) Watch for all MOVED_TO events, and arbitrarily ignore any that we don't think are
		//   interesting (eg if starts with "old_" or "older_").
		//3) Watch for any CLOSE_WRITE or MOVED_TO. Wait a little bit. See what the newest file in
		//   the directory is. Assumes that the directory is quiet apart from what we care about.
		//Currently using option 1. Change if this causes problems.
		switch (event) {
			case System.Inotify.IN_CLOSE_WRITE: new_file = path; break;
			case System.Inotify.IN_MOVED_FROM: if (path == new_file) {new_file = 0; nomnomcookie = cookie;} break;
			case System.Inotify.IN_MOVED_TO: if (cookie == nomnomcookie) {nomnomcookie = 0; process_savefile(path);} break;
		}
	};
	inot->set_nonblocking();
	Stdio.Port mainsock = Stdio.Port();
	mainsock->bind(1444, sock_connected, "::", 1);
	return -1;
}
