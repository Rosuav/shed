#define POLYGLOT "This script can be run as Python or Pike code. The Python code is client-only. \
"""
//Read a text (non-ironman) EU4 savefile and scan for matters of interest. Provides info to networked clients.
//TODO: Show a coalition as if it's a war?
//TODO: Raise highlighting priority of building upgrade options by a console command - or hide upgrades
//by default, show them only when explicitly requested (like the building highlighter), and then always
//have it at PRIO_EXPLICIT
//TODO: Allow input on the primary console, stateless infodumps only
/* TODO: browser mode
- Most of the same info that currently exists, but hide it behind details/summary
- Real-time updates that don't touch whether the detailses are open
- Easy way to do the things that currently need a command
- Whenever you hover any country name, show country details in an inset top-right
  - Show country tech level compared to yours (green = worse tech, red = better tech)
  - Flag? Can we show flags easily?
  - Click to go to country's capital
*/

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
	string encode_json(int flags, int indent) {
		//Only used if there's a hybrid maparray in the savefile (not in other files that don't
		//get cached in JSON) that can't be coalesced. Discard the indexed part.
		return Standards.JSON.encode(keyed, flags);
	}
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

//Parse a full directory of configs and merge them into one mapping
//The specified directory name should not end with a slash.
mapping parse_config_dir(string dir) {
	mapping ret = ([]);
	foreach (sort(get_dir(dir)), string fn)
		ret |= low_parse_savefile(Stdio.read_file(dir + "/" + fn));
	return ret;
}

mapping(string:string) L10n;
void parse_localisation(string data) {
	array lines = utf8_to_string("#" + data) / "\n"; //Hack: Pretend that the heading line is a comment
	foreach (lines, string line) {
		sscanf(line, "%s#", line);
		sscanf(line, " %s:%*d \"%s\"", string key, string val);
		if (key && val) L10n[key] = val;
	}
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
	return whole * 1000 + (int)sprintf("%.03s", frac + "000");
}

int interest_priority = 0;
array(string) interesting_province = ({ });
enum {PRIO_UNSET, PRIO_SITUATIONAL, PRIO_IMMEDIATE, PRIO_EXPLICIT};
void interesting(string id, int|void prio) {
	if (prio < interest_priority) return; //We've already had higher priority markers
	if (prio > interest_priority) {interest_priority = prio; interesting_province = ({ });} //Replace with new highest prio
	if (!has_value(interesting_province, id)) interesting_province += ({id}); //Retain order but avoid duplicates
}

mapping prov_area = ([]);
mapping province_info;
mapping building_types; array building_id;
mapping building_slots = ([]);
void analyze_cot(mapping data, string name, string tag, function|mapping write) {
	mapping country = data->countries[tag];
	mapping(string:int) area_has_level3 = country->area_has_level3 = ([]);
	array maxlvl = ({ }), upgradeable = ({ }), developable = ({ });
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (!prov->center_of_trade) continue;
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		int need = prov->center_of_trade == "1" ? 10 : 25;
		array desc = ({
			sprintf("%s %04d %s", prov->owner, 9999-dev, prov->name), //Sort key
			prov->center_of_trade, id, dev, prov->name,
		});
		if (prov->center_of_trade == "3") {maxlvl += ({desc}); area_has_level3[prov_area[id]] = (int)id;}
		else if (dev >= need) upgradeable += ({desc});
		else developable += ({desc});
	}
	sort(maxlvl); sort(upgradeable); sort(developable);
	int maxlevel3 = sizeof(country->merchants->envoy); //You can have as many lvl 3 CoTs as you have merchants.
	int level3 = sizeof(maxlvl); //You might already have some.
	string|mapping colorize(string color, array info, int prio) {
		//Colorize if it's interesting. It can't be upgraded if not in a state; also, not all level 2s
		//can become level 3s, for various reasons.
		[string key, string cotlevel, string id, int dev, string provname] = info;
		array have_states = data->map_area_data[prov_area[id]]->?state->?country_state->?country;
		string noupgrade;
		if (!have_states || !has_value(have_states, tag)) noupgrade = "is territory";
		else if (cotlevel == "2") {
			if (area_has_level3[prov_area[id]]) noupgrade = "other l3 in area";
			else if (++level3 > maxlevel3) noupgrade = "need merchants";
		}
		if (!noupgrade) interesting(id, prio);
		if (mappingp(write)) return (["id": id, "dev": dev, "name": provname, "noupgrade": noupgrade || "", "level": (int)cotlevel]);
		string desc = sprintf("%s\tLvl %s\tDev %d\t%s", id, cotlevel, dev, string_to_utf8(provname));
		if (noupgrade) return sprintf("%s [%s]", desc, noupgrade);
		else return color + desc;
	}
	if (mappingp(write)) {
		write->cot = ([
			"level3": level3, "max": maxlevel3,
			"upgradeable": colorize("", upgradeable[*], PRIO_IMMEDIATE),
			"developable": colorize("", developable[*], PRIO_SITUATIONAL),
		]);
		return;
	}
	if (sizeof(maxlvl)) write("Max level CoTs (%d/%d):\n%{%s\n%}\n", level3, maxlevel3, maxlvl[*][-1]);
	else write("Max level CoTs: 0/%d\n", maxlevel3);
	if (sizeof(upgradeable)) write("Upgradeable CoTs:\n%{%s\e[0m\n%}\n", colorize("\e[1;32m", upgradeable[*], PRIO_IMMEDIATE));
	if (sizeof(developable)) write("Developable CoTs:\n%{%s\e[0m\n%}\n", colorize("\e[1;36m", developable[*], PRIO_SITUATIONAL));
}

object calendar(string date) {
	sscanf(date, "%d.%d.%d", int year, int mon, int day);
	return Calendar.Gregorian.Day(year, mon, day);
}

mapping idea_definitions, policy_definitions, reform_definitions, static_modifiers, trade_goods, country_modifiers, age_definitions;
//List all ideas (including national) that are active
array(mapping) enumerate_ideas(mapping idea_groups) {
	array ret = ({ });
	foreach (idea_groups; string grp; string numtaken) {
		mapping group = idea_definitions[grp]; if (!group) continue;
		ret += ({group->start}) + group->ideas[..(int)numtaken - 1];
		if (numtaken == "7") ret += ({group->bonus});
	}
	return ret - ({0});
}

//Gather ALL a country's modifiers. Or, try to.
void _incorporate(mapping modifiers, mapping effect, int|void mul, int|void div) {
	if (effect) foreach (effect; string id; mixed val) {
		if ((id == "modifier" || id == "modifiers") && mappingp(val)) _incorporate(modifiers, val, mul, div);
		if (stringp(val) && sscanf(val, "%[-]%d%*[.]%[0-9]%s", string sign, int whole, string frac, string blank) && blank == "")
			modifiers[id] += (sign == "-" ? -1 : 1) * (whole * 1000 + (int)sprintf("%.03s", frac + "000")) * (mul||1) / (div||1);
	}
}
mapping estate_definitions = ([]), estate_privilege_definitions = ([]);
mapping(string:int) all_country_modifiers(mapping data, mapping country) {
	if (mapping cached = country->all_country_modifiers) return cached;
	mapping modifiers = ([]);
	//TODO: Add more things here as they get analyzed
	foreach (enumerate_ideas(country->active_idea_groups), mapping idea) _incorporate(modifiers, idea);
	foreach (Array.arrayify(country->active_policy), mapping policy)
		_incorporate(modifiers, policy_definitions[policy->policy]);
	foreach (Array.arrayify(country->government->reform_stack->reforms), string reform)
		_incorporate(modifiers, reform_definitions[reform]);
	foreach (Array.arrayify(country->traded_bonus), string idx)
		_incorporate(modifiers, trade_goods[(int)idx]);
	foreach (Array.arrayify(country->modifier), mapping mod)
		_incorporate(modifiers, country_modifiers[mod->modifier]);
	mapping age = age_definitions[data->current_age]->abilities;
	_incorporate(modifiers, age[Array.arrayify(country->active_age_ability)[*]][*]);
	//More modifier types to incorporate:
	//- Monuments. Might be hard, since they have restrictions. Can we see in the savefile if they're active?
	//- Religious modifiers (icons, cults, aspects, etc)
	//- Government type modifiers (eg march, vassal, colony)

	if (country->luck) _incorporate(modifiers, static_modifiers->luck); //Lucky nations (AI-only) get bonuses.
	//Having gone through all of the above, we should now have estate influence modifiers.
	//Now we can calculate the total influence, and then add in the effects of each estate.
	if (country->estate) {
		//Some estates might not work like this. Not sure.
		//First, incorporate country-wide modifiers from privileges. (It's possible for privs to
		//affect other estates' influences.)
		foreach (country->estate, mapping estate) {
			foreach (Array.arrayify(estate->granted_privileges), [string priv, string date]) {
				mapping privilege = estate_privilege_definitions[priv];
				_incorporate(modifiers, privilege->penalties);
				_incorporate(modifiers, privilege->benefits);
			}
		}
		//Now calculate the influence and loyalty of each estate, and the resulting effects.
		foreach (country->estate, mapping estate) {
			mapping estate_defn = estate_definitions[estate->type];
			if (!estate_defn) continue;
			int influence = (int)estate_defn->base_influence * 1000;
			//There are some conditional modifiers. Sigh. This is seriously complicated. Why can't estate influence just be in the savefile?
			foreach (Array.arrayify(estate->granted_privileges), [string priv, string date])
				influence += threeplace(estate_privilege_definitions[priv]->?influence) * 100;
			influence += modifiers[replace(estate->type, "estate_", "") + "_influence_modifier"] * 100;
			foreach (Array.arrayify(estate->influence_modifier), mapping mod)
				influence += threeplace(mod->value);
			influence += threeplace(estate->territory) / 2; //Is this always the case? 42% land share gives 21% influence?
			//This is horribly incomplete. Needs a lot of expansion to truly be useful.
			string opinion = "neutral";
			if ((float)estate->loyalty >= 60.0) opinion = "happy";
			else if ((float)estate->loyalty < 30.0) opinion = "angry";
			int mul = 4;
			if (influence < 60000) mul = 3;
			if (influence < 40000) mul = 2;
			if (influence < 20000) mul = 1;
			_incorporate(modifiers, estate_defn["country_modifier_" + opinion], mul, 4);
		}
	}
	return country->all_country_modifiers = modifiers;
}

//Estimate a months' production of ducats/manpower/sailors (yes, I'm fixing the scaling there)
array(float) estimate_per_month(mapping data, mapping country) {
	float gold = (float)country->ledger->lastmonthincome - (float)country->ledger->lastmonthexpense;
	float manpower = (float)country->max_manpower * 1000 / 120.0;
	float sailors = (float)country->max_sailors / 120.0;
	//Attempt to calculate modifiers. This is not at all accurate but should give a reasonable estimate.
	float mp_mod = 1.0, sail_mod = 1.0;
	mp_mod += (float)country->army_tradition * 0.001;
	sail_mod += (float)country->navy_tradition * 0.002;
	mp_mod -= (float)country->war_exhaustion / 100.0;
	sail_mod -= (float)country->war_exhaustion / 100.0;
	mapping modifiers = all_country_modifiers(data, country);
	mp_mod += modifiers->manpower_recovery_speed / 1000.0;
	sail_mod += modifiers->sailors_recovery_speed / 1000.0;

	//Add back on the base manpower recovery (10K base manpower across ten years),
	//which isn't modified by recovery bonuses/penalties. Doesn't apply to sailors
	//as there's no "base sailors".
	//CJA 20211224: Despite what the wiki says, it seems this isn't the case, and
	//manpower recovery modifiers are applied to the base 10K as well.
	manpower = manpower * mp_mod; sailors *= sail_mod;
	return ({gold, max(manpower, 100.0), max(sailors, sailors > 0.0 ? 5.0 : 0.0)}); //There's minimum manpower/sailor recovery
}

void analyze_leviathans(mapping data, string name, string tag, function|mapping write) {
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
				({"", id, "Lvl " + proj->development_tier, prov->name, L10n[project] || "#" + project,
					con->great_projects != project ? "" : //If you're upgrading a different great project in this province, leave this one blank (you can't upgrade two at once)
					sprintf("%s%d%%, due %s",
						con->type == "2" ? "Moving: " : "", //Upgrades are con->type "1", moving to capital is type "2"
						threeplace(con->progress) / 10, con->date),
				}),
			})});
			//write("Project: %O\n", proj);
		}
		//if (con) write("Construction: %O\n", con);
	}
	sort(projects);
	object today = calendar(data->date);
	array cooldowns = ({ });
	mapping cd = country->cooldowns || ([]);
	array(float) permonth = estimate_per_month(data, country);
	foreach ("gold men sailors" / " "; int i; string tradefor) {
		string date = cd["trade_favors_for_" + tradefor];
		string cur = sprintf("%.3f", permonth[i] * 6);
		if (!date) {cooldowns += ({({"", "---", "--------", String.capitalize(tradefor), cur})}); continue;}
		int days = today->distance(calendar(date)) / today;
		cooldowns += ({({"", days, date, String.capitalize(tradefor), cur})}); //TODO: Don't include the initial empty string here, add it for tabulate() only
	}
	if (mappingp(write)) {
		write->monuments = projects[*][-1];
		//Favors are all rendered on the front end.
		mapping owed = ([]);
		foreach (data->countries; string other; mapping c) {
			int favors = threeplace(c->active_relations[tag]->?favors);
			if (favors > 0) owed[c->name || L10n[other] || other] = ({favors / 1000.0}) + estimate_per_month(data, c)[*] * 6;
		}
		write->favors = (["cooldowns": cooldowns, "owed": owed]);
		return;
	}
	if (sizeof(projects)) write("%s\n", string_to_utf8(tabulate(({""}) + "ID Tier Province Project Upgrading" / " ", projects[*][-1], "  ", 0)));
	write("\nFavors:\n");
	foreach (data->countries; string other; mapping c) {
		int favors = threeplace(c->active_relations[tag]->?favors);
		if (favors > 1000) write("%s owes you %d.%03d\n", c->name || L10n[other] || other, favors / 1000, favors % 1000);
	}
	write("%s\n", string_to_utf8(tabulate(({"", "Days", "Date", "Trade for", "Max gain"}), cooldowns, "  ", 0)));
}

int count_building_slots(mapping data, string id) {
	//Count building slots. Not perfect. Depends on the CoTs being provided accurately.
	//Doesn't always give the terrain bonus.
	int slots = 2 + building_slots[id]; //All cities get 2, plus possibly a bonus from terrain and/or a penalty from climate.
	mapping prov = data->provinces["-" + id];
	if (prov->buildings->?university) ++slots; //A university effectively doesn't consume a slot.
	if (data->countries[prov->owner]->?area_has_level3[?prov_area[id]]) ++slots; //A level 3 CoT in the state adds a building slot
	//TODO: Modifiers, incl event flags (see all_country_modifiers maybe?)
	int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
	return slots + dev / 10;
}

mapping(string:string) manufactories = ([]); //Calculated from building_types
void analyze_furnace(mapping data, string name, string tag, function|mapping write) {
	if (mappingp(write)) return; //TODO UNSUPPORTED
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
			if (prov->building_construction) {
				//There's something being built. That consumes a slot, but if it's an
				//upgrade, then that slot doesn't really count. If you have four slots,
				//four buildings, and one of them is being upgraded, the game will show
				//that there are five occupied slots and none open; for us here, it's
				//cleaner to show it as 4/4.
				++buildings;
				string upg = building_id[(int)prov->building_construction->building];
				while (string was = building_types[upg]->make_obsolete) {
					if (bldg[was]) {--buildings; break;}
					upg = was;
				}
			}
			interesting(id, PRIO_IMMEDIATE); //TODO: Should it always be highlighted at the same prio? Should it always even be highlighted?
			write("\e[1;%dm%s\t%d/%d bldg\tDev %d\t%s%s\e[0m\n", buildings < slots ? 32 : 36, id, buildings, slots, dev,
				string_to_utf8(prov->name), prov->settlement_growth_construction ? " - SETTLER ACTIVE" : ""); //Can't build while there's a settler promoting growth);
		}
	}
	if (seen) write("\n");
}

void analyze_upgrades(mapping data, string name, string tag, function|mapping write) {
	if (mappingp(write)) return; //TODO UNSUPPORTED
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
			if (target && target != constructing) {interesting(id, PRIO_SITUATIONAL); upgradeables[target] += ({prov->name});}
		}
	}
	foreach (sort(indices(upgradeables)), string b) {
		write("Can upgrade %d buildings to %s\n", sizeof(upgradeables[b]), b);
		write("==> %s\n", string_to_utf8(upgradeables[b] * ", "));
	}
}

void analyze_findbuildings(mapping data, string name, string tag, function|mapping write, string highlight) {
	werror("findbuildings: mappingp %d highlight %O\n", mappingp(write), highlight);
	if (mappingp(write)) return; //TODO UNSUPPORTED
	mapping country = data->countries[tag];
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		//Building shipyards in inland provinces isn't very productive
		if (building_types[highlight]->build_trigger->?has_port && !province_info[id]->?has_port) continue;
		mapping bldg = prov->buildings || ([]);
		int slots = count_building_slots(data, id);
		int buildings = sizeof(bldg);
		if (prov->building_construction) {
			//Duplicate of the above
			++buildings;
			string upg = building_id[(int)prov->building_construction->building];
			while (string was = building_types[upg]->make_obsolete) {
				if (bldg[was]) {--buildings; break;}
				upg = was;
			}
		}
		if (buildings < slots) continue; //Got room. Not a problem. (Note that the building slots calculation may be wrong but usually too low.)
		//Check if a building of the highlight type already exists here.
		int gotone = 0;
		foreach (prov->buildings; string b;) {
			while (string upg = building_types[b]->make_obsolete) b = upg;
			if (b == highlight) {gotone = 1; break;}
		}
		if (gotone) continue;
		interesting(id, PRIO_EXPLICIT);
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		write("\e[1;32m%s\t%d/%d bldg\tDev %d\t%s\e[0m\n", id, buildings, slots, dev, string_to_utf8(prov->name));
	}
}

mapping(string:array) interesting_provinces = ([]);
void analyze(mapping data, string name, string tag, function|mapping|void write, string|void highlight) {
	if (!write) write = Stdio.stdin->write;
	interesting_province = ({ }); interest_priority = 0;
	if (mappingp(write)) write->name = name + " (" + (data->countries[tag]->name || L10n[tag] || tag) + ")";
	else write("\e[1m== Player: %s (%s) ==\e[0m\n", name, tag);
	({analyze_cot, analyze_leviathans, analyze_furnace, analyze_upgrades})(data, name, tag, write);
	if (highlight) analyze_findbuildings(data, name, tag, write, highlight);
	//write("* %s * %s\n\n", tag, Standards.JSON.encode((array(int))interesting_province)); //If needed in a machine-readable format
	interesting_provinces[tag] = interesting_province;
}

//Not currently triggered from anywhere. Doesn't currently have a primary use-case.
void show_tradegoods(mapping data, string tag, function|void write) {
	//write("Sevilla: %O\n", data->provinces["-224"]);
	//write("Demnate: %O\n", data->provinces["-4568"]);
	mapping prod = ([]), count = ([]);
	mapping country = data->countries[tag];
	float prod_efficiency = 1.0;
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		//1) Goods produced: base production * 0.2 + flat modifiers (eg Manufactory)
		int production = threeplace(prov->base_production) / 5;
		//2) Trade value: goods * price
		float trade_value = production * (float)data->change_price[prov->trade_goods]->current_price / 1000;
		//3) Prod income: trade value * national efficiency * local efficiency * (1 - autonomy)
		float local_efficiency = 1.0, autonomy = 0.0; //TODO.
		float prod_income = trade_value * prod_efficiency * local_efficiency * (1.0 - autonomy);
		//Done. Now gather the stats.
		prod[prov->trade_goods] += prod_income;
		count[prov->trade_goods]++;
	}
	float total_value = 0.0;
	array goods = indices(prod); sort(-values(prod)[*], goods);
	foreach (goods, string tradegood) {
		float annual_value = prod[tradegood];
		if (annual_value > 0) write("%.2f/year from %d %s provinces\n", annual_value, count[tradegood], tradegood);
		total_value += annual_value;
	}
	write("Total %.2f/year or %.4f/month\n", total_value, total_value / 12);
}

void analyze_flagships(mapping data, function|mapping write) {
	array flagships = ({ });
	foreach (data->countries; string tag; mapping country) {
		//mapping country = data->countries[tag];
		if (!country->navy) continue;
		foreach (Array.arrayify(country->navy), mapping fleet) {
			foreach (Array.arrayify(fleet->ship), mapping ship) {
				if (!ship->flagship) continue;
				string was = ship->flagship->is_captured && ship->flagship->original_owner;
				string cap = was ? " CAPTURED from " + (data->countries[was]->name || L10n[was] || was) : "";
				if (mappingp(write)) flagships += ({({
					country->name || L10n[tag] || tag, fleet->name,
					String.capitalize(ship->type), ship->name,
					ship->flagship->modification,
					ship->flagship->is_captured ? (data->countries[was]->name || L10n[was] || was) : ""
				})});
				else flagships += ({({
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
	sort(flagships);
	if (mappingp(write)) {write->flagships = flagships; return;}
	if (!sizeof(flagships)) return;
	write("\n\e[1m== Flagships of the World ==\e[0m\n");
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
	"heavy_ship: early_carrack carrack galleon wargalleon twodecker threedecker ",
	"light_ship: barque caravel early_frigate frigate heavy_frigate great_frigate ",
	"galley: galley war_galley galleass galiot chebeck archipelago_frigate ",
	"transport: war_canoe cog flute brig merchantman trabakul eastindiaman ",
);

void analyze_wars(mapping data, multiset(string) tags, function|mapping|void write) {
	if (!write) write = Stdio.stdin->write;
	if (mappingp(write)) write->wars = ({ });
	foreach (values(data->active_war || ({ })), mapping war) {
		if (!mappingp(war)) continue; //Dunno what's with these, there seem to be some strings in there.
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
		mapping summary = (["date": war->action, "name": war->name, "raw": war, "atk": is_attacker, "def": is_defender]);
		summary->cb = war->superiority || war->take_province || war->blockade_ports || (["casus_belli": "(none)"]);
		//TODO: See if there are any other war goals
		//NOTE: In a no-CB war, there is no war goal, so there'll be no attribute to locate.
		if (mappingp(write)) write->wars += ({summary});
		else write("\n\e[1;31m== War: %s - %s ==\e[0m\n", war->action, string_to_utf8(war->name));
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
		summary->participants = ({ });
		foreach (war->participants, mapping p) {
			mapping partic = (["tag": p->tag]);
			summary->participants += ({partic});
			mapping country = data->countries[p->tag];
			int a = has_value(war->attackers, p->tag), d = has_value(war->defenders, p->tag);
			if (!a && !d) continue; //War participant has subsequently peaced out
			partic->attacker = a; partic->defender = d; partic->player = tags[p->tag];
			string side = sprintf("\e[48;2;%d;%d;%dm%s  ",
				a && 30, //Red for attacker
				tags[p->tag] && 60, //Cyan or olive for player
				d && 30,
				a ? atk : def, //Sword or shield
			);
			if (mappingp(write)) side = (({a && "attacker", d && "defender", tags[p->tag] && "player"}) - ({0})) * ",";
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
		string atot = "\e[48;2;50;0;0m" + atk + "  ", dtot = "\e[48;2;0;0;50m" + def + "  ";
		if (mappingp(write)) {atot = "attacker,total"; dtot="defender,total";}
		armies += ({
			//The totals get sorted after the individual country entries. Their sort keys are
			//guaranteed positive, and are such that the larger army has a smaller sort key.
			//Easiest way to do that is to swap them :)
			({1 + army_total[1][-2] + army_total[1][-1], ({atot, ""}) + army_total[0] + ({"", ""})}),
			({1 + army_total[0][-2] + army_total[0][-1], ({dtot, ""}) + army_total[1] + ({"", ""})}),
		});
		navies += ({
			({1 + navy_total[1][-2] + navy_total[1][-1], ({atot, ""}) + navy_total[0] + ({""})}),
			({1 + navy_total[0][-2] + navy_total[0][-1], ({dtot, ""}) + navy_total[1] + ({""})}),
		});
		sort(armies); sort(navies);
		if (mappingp(write)) {summary->armies = armies[*][-1]; summary->navies = navies[*][-1]; continue;}
		write("%s\n", string_to_utf8(tabulate(({"   "}) + "Country Infantry Cavalry Artillery Inf$$ Cav$$ Art$$ Total Manpower Prof Trad" / " ", armies[*][-1], "  ", 2)));
		write("%s\n", string_to_utf8(tabulate(({"   "}) + "Country Heavy Light Galley Transp Total Sailors Trad" / " ", navies[*][-1], "  ", 2)));
	}
}

mapping(string:multiset(object)) connections = (["": (<>), "province": (<>)]);
mapping last_parsed_savefile;
class Connection(Stdio.File sock) {
	Stdio.Buffer incoming = Stdio.Buffer(), outgoing = Stdio.Buffer();
	string notiftype = "";
	string notify, highlight;

	protected void create() {
		//write("%%%% Connection from %s\n", sock->query_address());
		sock->set_buffer_mode(incoming, outgoing);
		sock->set_nonblocking(sockread, 0, sockclosed);
	}
	void sockclosed() {connections[notiftype][this] = 0; sock->close();}

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

	void provnotify(string country, int province) {
		//A request has come in to notify a country to focus on a province.
		if (!notify) return;
		string tag = find_country(last_parsed_savefile, notify);
		if (tag != country) return; //Not found, or not for us.
		outgoing->sprintf("provfocus %d\n", province);
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
					connections[notiftype][this] = 0;
					if (sscanf(arg, "province %s", arg)) notiftype = "province";
					notify = arg; connections[notiftype][this] = 1;
					if (notiftype == "" && last_parsed_savefile) inform(last_parsed_savefile);
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
int parsing = 0;
void process_savefile(string fn) {parsing = 1; send_updates_all(); parser_pipe->write(fn + "\n");}
void done_processing_savefile() {
	parser_pipe->read();
	mapping data = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}")->data;
	if (!data) {werror("Unable to parse save file (see above for errors, hopefully)\n"); return;}
	write("\nCurrent date: %s\n", data->date);
	foreach (data->players_countries / 2, [string name, string tag]) analyze(data, name, tag);
	analyze_wars(data, (multiset)(data->players_countries / 2)[*][1]);
	indices(connections[""])->inform(data);
	last_parsed_savefile = data;
	parsing = 0; send_updates_all();
}

class ClientConnection {
	inherit Connection;
	protected void create(Stdio.File sock) {
		::create(sock);
		Stdio.stdin->set_read_callback(stdinread);
		Stdio.stdin->set_close_callback(stdineof);
	}
	int keysend_provid;
	mixed keysend_callout;
	void find_eu4() {
		//Check which window has focus. If it seems to be EU4, poke keys, otherwise wait.
		mapping focus = Process.run(({"xdotool", "getactivewindow", "getwindowname"}));
		if (!has_value(focus->stdout, "Europa Universalis IV")) {keysend_callout = call_out(find_eu4, 0.5); return;}
		keysend_callout = 0;
		//TODO: Allow search mode instead of the above retry loop waiting for focus
		Process.create_process(({"xdotool",
			//"search", "--name", "Europa Universalis IV",
			"key", "--delay", "125", //Hurry the typing along a bit
			"f", @((string)keysend_provid / ""), "Return", //Send "f", then type the province ID, then hit Enter
		}))->wait();
	}
	void sockread() {
		//Display only complete lines, to avoid disruption of input text
		while (array ret = incoming->sscanf("%s\n")) {
			write("%s\n", ret[0]);
			if (sscanf(ret[0], "provfocus %d", int provid) && provid) {
				keysend_provid = provid;
				if (keysend_callout) continue; //Already waiting. Replace the province ID with a new one.
				keysend_callout = call_out(find_eu4, 0);
			}
		}
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

mapping(string:array(object)) websocket_groups = ([]);
mapping respond(Protocols.HTTP.Server.Request req) {
	mapping mimetype = (["eu4_parse.js": "text/javascript", "eu4_parse.css": "text/css"]);
	if (string ty = mimetype[req->not_query[1..]]) return ([
		"type": ty, "file": Stdio.File(req->not_query[1..]),
		"extra_heads": (["Access-Control-Allow-Origin": "*"]),
	]);
	if (req->not_query == "/" || sscanf(req->not_query, "/tag/%s", string tag)) return ([
		"type": "text/html",
		"data": sprintf(#"<!DOCTYPE HTML><html lang=en>
<head><title>EU4 Savefile Analysis</title><link rel=stylesheet href=\"/eu4_parse.css\"></head>
<body><script>
let ws_code = new URL(\"/eu4_parse.js\", location.href), ws_type = \"eu4\", ws_group = \"%s\";
let ws_sync = null; import('https://sikorsky.rosuav.com/static/ws_sync.js').then(m => ws_sync = m);
</script><main></main></body></html>
", tag || "?!?"),
	]);
	if (req->not_query == "/search") {
		//TODO: Search for a country by tag, name, etc. Return a redirect to /tag/%s, or maybe a menu.
		return NOT_FOUND;
	}
}
constant NOT_FOUND = (["error": 404, "type": "text/plain", "data": "Not found"]);
void http_handler(Protocols.HTTP.Server.Request req) {req->response_and_finish(respond(req) || NOT_FOUND);}

mapping(string:string) highlight_interesting = ([]); //On the websocket, this choice applies to all connections for that user (to prevent inexplicable loss of config on dc)
void websocket_cmd_highlight(mapping conn, mapping data) {
	highlight_interesting[conn->group] = data->building;
	send_update(websocket_groups[conn->group], get_state(conn->group) | (["parsing": parsing]));
}

void websocket_cmd_goto(mapping conn, mapping data) {
	indices(connections["province"])->provnotify(data->tag, (int)data->province);
}

void ws_msg(Protocols.WebSocket.Frame frm, mapping conn)
{
	mixed data;
	if (catch {data = Standards.JSON.decode(frm->text);}) return; //Ignore frames that aren't text or aren't valid JSON
	if (!stringp(data->cmd)) return;
	if (data->cmd == "init")
	{
		//Initialization is done with a type and a group.
		//The type has to be "eu4", and exists for convenient compatibility with StilleBot.
		//The group is a country tag as a string.
		if (conn->type) return; //Can't init twice
		if (data->type != "eu4") return; //Ignore any unknown types.
		//Note that we don't validate the group here, beyond basic syntactic checks. We might have
		//the wrong save loaded, in which case the precise country tag won't yet exist.
		if (!stringp(data->group)) return;
		write("Socket connection established for %O\n", data->group);
		conn->type = data->type; conn->group = data->group;
		websocket_groups[conn->group] += ({conn->sock});
		send_update(({conn->sock}), get_state(data->group));
		return;
	}
	if (function handler = this["websocket_cmd_" + data->cmd]) handler(conn, data);
	else write("Message: %O\n", data);
}

void ws_close(int reason, mapping conn)
{
	if (conn->type == "eu4") websocket_groups[conn->group] -= ({conn->sock});
	m_delete(conn, "sock"); //De-floop
}

void ws_handler(array(string) proto, Protocols.WebSocket.Request req)
{
	if (req->not_query != "/ws") {req->response_and_finish(NOT_FOUND); return;}
	Protocols.WebSocket.Connection sock = req->websocket_accept(0);
	sock->set_id((["sock": sock])); //Minstrel Hall style floop
	sock->onmessage = ws_msg;
	sock->onclose = ws_close;
}

void send_update(array(object) socks, mapping state) {
	if (!socks || !sizeof(socks)) return;
	string resp = Standards.JSON.encode((["cmd": "update"]) | state);
	foreach (socks, object sock)
		if (sock && sock->state == 1) sock->send_text(resp);
}

void send_updates_all() {foreach (websocket_groups; string tag; array grp) send_update(grp, get_state(tag) | (["parsing": parsing]));}

mapping get_state(string group) {
	mapping data = last_parsed_savefile; //Get a local reference in case it changes while we're processing
	if (!data) return (["error": "Processing savefile..."]);
	//For the landing page, offer a menu of player countries
	if (group == "?!?") return (["menu": data->players_countries / 2]);
	string tag = group;
	if (!data->countries[tag]) {
		//See if it's a player identifier. These get rechecked every get_state
		//because they will track the player through tag changes (eg if you were
		//Castille (CAS) and you form Spain (SPA), your tag will change, but you
		//want to see data for Spain now plsthx).
		foreach (data->players_countries / 2, [string name, string trytag])
			if (lower_case(tag) == lower_case(name)) tag = trytag;
	}
	mapping country = data->countries[tag];
	if (!country) return (["error": "Country/player not found: " + group]);
	mapping ret = (["tag": tag, "self": data->countries[tag]]);
	analyze(data, group, tag, ret, highlight_interesting[group]);
	analyze_wars(data, (multiset)(data->players_countries / 2)[*][1], ret);
	analyze_flagships(data, ret);
	return ret;
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
	retain_map_indices = 1;
	idea_definitions = parse_config_dir(PROGRAM_PATH + "/common/ideas");
	retain_map_indices = 0;
	foreach (idea_definitions; string grp; mapping group) {
		array basic_ideas = ({ }), pos = ({ });
		mapping tidied = ([]);
		foreach (group; string id; mixed idea) {
			if (!mappingp(idea)) continue;
			int idx = m_delete(idea, "_index");
			if (id == "start" || id == "bonus") {tidied[id] = idea; continue;}
			if ((<"trigger", "free", "category", "ai_will_do">)[id]) continue;
			basic_ideas += ({idea});
			pos += ({idx});
		}
		sort(pos, basic_ideas);
		tidied->ideas = basic_ideas;
		idea_definitions[grp] = tidied;
	}
	policy_definitions = parse_config_dir(PROGRAM_PATH + "/common/policies");
	estate_definitions = parse_config_dir(PROGRAM_PATH + "/common/estates");
	estate_privilege_definitions = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/estate_privileges/00_privileges.txt"));
	reform_definitions = parse_config_dir(PROGRAM_PATH + "/common/government_reforms");
	static_modifiers = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/static_modifiers/00_static_modifiers.txt"));
	retain_map_indices = 1;
	trade_goods = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/tradegoods/00_tradegoods.txt"));
	retain_map_indices = 0;
	foreach (trade_goods; string id; mapping info) {
		trade_goods[info->_index + 1] = info;
		info->id = id;
	}
	country_modifiers = parse_config_dir(PROGRAM_PATH + "/common/event_modifiers")
		| parse_config_dir(PROGRAM_PATH + "/common/parliament_issues");
	age_definitions = parse_config_dir(PROGRAM_PATH + "/common/ages");

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
	Protocols.WebSocket.Port(http_handler, ws_handler, 8087, "::");
	return -1;
}
#ifdef G
#define POLYGLOT2 "End of Pike code. \
"""
# Python code follows. This should be restricted to the standard library and as broadly
# compatible as possible (currently aiming for 3.7-3.11). It should have all the basic
# client-side functionality and that is all.

import socket
import subprocess
import sys
import time
# First arg is server name/IP; the rest are joined and sent as a command.
# If the second arg is "province", then the result is fed as keys to EU4.
# Otherwise, this is basically like netcat/telnet.
if len(sys.argv) < 3:
	print("USAGE: python3 %s ipaddress command")
	print("Useful commands include 'notify Name' and 'notify province Name'")
	sys.exit(0)

def goto(provid):
	# NOTE: This is currently synchronous, unlike the Pike version, which is
	# fully asynchronous. So if you queue multiple and then switch focus to
	# EU4, it will go through all of them.
	while "looking for EU4":
		proc = subprocess.run(["xdotool", "getactivewindow", "getwindowname"], encoding="UTF-8", capture_output=True, check=True)
		if "Europa Universalis IV" in proc.stdout: break
		time.sleep(0.5)
	subprocess.run(["xdotool", "key", "--delay", "125", "f", *list(str(provid)), "Return"], check=True)


sock = socket.create_connection((sys.argv[1], 1444))
sock.send(" ".join(sys.argv[2:]).encode("UTF-8") + b"\n")
partial = b""
while "moar data":
	data = sock.recv(1024)
	if not data: break
	[*lines, data] = (partial + data).split(b"\n")
	for line in lines:
		line = line.decode("UTF-8")
		if sys.argv[2] == "province":
			# Special case: go-to-province-now
			goto(int(line))
			sys.exit(0)
		print(line)
		if line.startswith("provfocus "): goto(int(line.split(" ")[1]))

#endif
