#define POLYGLOT "This script can be run as Python or Pike code. The Python code is client-only. \
"""
//Read a text (non-ironman) EU4 savefile and scan for matters of interest. Provides info to networked clients.
/*
NOTE: Province group selection inverts the normal rules and has the web client in charge.
This ensures that there can be no desynchronization between user view and province ID
selection, but it does mean that the client must remain active in order to keep things
synchronized. In practice, not a problem, since the client selects the group anyway.
*/
//TODO: Background service to do the key sending. See example systemd script in my cfgsystemd.

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
	multiset _is_auto_array = (<>);
	object addkey(string key, mixed value) {
		//HACK: Track country order even though the rest of the file isn't tracked that way
		//If Pike had an order-retaining mapping, this would be unnecessary. Hmm.
		if (key == "---" && !retain_map_indices) retain_map_indices = 2;
		if (key == "countries" && retain_map_indices == 2) retain_map_indices = 0;
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
			case "_is_auto_array": return _is_auto_array;
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
	//To properly handle arrays of arrays, we keep track of every key for which such
	//auto-collection has been done.
	if (map->_is_auto_array[name]) map[name] += ({val});
	else if (map[name]) {map[name] = ({map[name], val}); map->_is_auto_array[name] = 1;}
	else map->addkey(name, val);
	return map;
}
maparray makearray(mixed val) {return maparray()->addidx(val);}
maparray addarray(maparray arr, mixed val) {return arr->addidx(val);}
mapping emptymaparray() {return ([]);}

object progress_pipe;
constant PARSE_PROGRESS_FRACTION = 20; //Report at 1/10, 2/10, 3/10 etc of progress
mapping low_parse_savefile(string|Stdio.Buffer data, int|void verbose) {
	if (stringp(data)) data = Stdio.Buffer(data); //NOTE: Restricted to eight-bit data. Since EU4 uses ISO-8859-1, that's not a problem. Be aware for future.
	data->read_only();
	string ungetch;
	int totsize = sizeof(data), fraction = totsize / PARSE_PROGRESS_FRACTION, nextmark = totsize - fraction;
	string|array next() {
		int progress = sizeof(data);
		if (progress_pipe && progress < nextmark) {nextmark -= fraction; progress_pipe->write("+");}
		if (string ret = ungetch) {ungetch = 0; return ret;}
		data->sscanf("%*[ \t\r\n]");
		while (data->sscanf( "#%*s\n%*[ \t\r\n]")); //Strip comments
		if (!sizeof(data)) return "";
		if (array str = data->sscanf("\"%[^\"]\"")) {
			//How are embedded quotes and/or backslashes handled?
			return ({"string", str[0]});
		}
		if (array digits = data->sscanf("%[-0-9.]")) {
			if (array hex = digits[0] == "0" && data->sscanf("x%[0-9a-fA-F]")) return ({"string", "0x" + hex[0]}); //Or should this be converted to decimal?
			return ({"string", digits[0]});
		}
		if (array|string word = data->sscanf("%[0-9a-zA-Z_'\x81-\xFE:]")) { //Include non-ASCII characters as letters
			word = word[0];
			//Unquoted tokens like institution_events.2 should be atoms, not atom-followed-by-number
			if (array dotnumber = data->sscanf(".%[0-9]")) word += "." + dotnumber[0];
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

mapping parse_savefile_string(string data, string|void filename) {
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
	if (filename) write("Reading save file %s (%d bytes)...\n", filename, sizeof(data));
	return low_parse_savefile(data);
}

mapping parse_savefile(string data, string|void filename) {
	sscanf(Crypto.SHA256.hash(data), "%32c", int hash);
	string hexhash = sprintf("%64x", hash);
	mapping cache = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}");
	if (cache->hash == hexhash) return cache->data;
	mapping ret = parse_savefile_string(data, filename);
	if (!ret) return 0; //Probably an Ironman save (binary format, can't be parsed by this system).
	foreach (ret->countries; string tag; mapping c) c->tag = tag; //When looking at a country, it's often convenient to know its tag (reverse linkage).
	Stdio.write_file("eu4_parse.json", string_to_utf8(Standards.JSON.encode((["hash": hexhash, "data": ret]))));
	return ret;
}

//Parse a full directory of configs and merge them into one mapping
//The specified directory name should not end with a slash.
//If key is provided, will return only that key from each file.
mapping parse_config_dir(string dir, string|void key) {
	mapping ret = ([]);
	foreach (sort(get_dir(dir)), string fn) {
		mapping cur = low_parse_savefile(Stdio.read_file(dir + "/" + fn) + "\n") || ([]);
		if (key) cur = cur[key] || ([]);
		ret |= cur;
	}
	return ret;
}

mapping(string:string) L10n, province_localised_names;
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

mapping prov_area = ([]), map_areas = ([]);
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
	int maxprio = 0;
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
		if (!noupgrade) {interesting(id, prio); maxprio = max(prio, maxprio);}
		if (mappingp(write)) return (["id": id, "dev": dev, "name": provname, "noupgrade": noupgrade || "", "level": (int)cotlevel, "interesting": !noupgrade && prio]);
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
		write->cot->maxinteresting = maxprio;
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

mapping idea_definitions, policy_definitions, reform_definitions, static_modifiers;
mapping trade_goods, country_modifiers, age_definitions, tech_definitions, institutions;
mapping cot_definitions, state_edicts, terrain_definitions, imperial_reforms;
mapping cb_types, wargoal_types, estate_agendas, country_decisions, country_missions;
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

//Gather ALL a country's modifiers. Or, try to. Note that conditional modifiers aren't included.
void _incorporate(mapping data, mapping modifiers, mapping effect, int|void mul, int|void div) {
	if (effect) foreach (effect; string id; mixed val) {
		if ((id == "modifier" || id == "modifiers") && mappingp(val)) _incorporate(data, modifiers, val, mul, div);
		if (id == "conditional" && mappingp(val)) {
			//Conditional attributes. We understand a very limited set of them here.
			//If in doubt, incorporate them. That might be an unideal default though.
			int ok = 1;
			foreach (val->allow || ([]); string key; string val) switch (key) {
				case "has_dlc": if (!has_value(data->dlc_enabled, val)) ok = 0; break;
				default: break;
			}
			if (ok) _incorporate(data, modifiers, val, mul, div);
		}
		if (id == "custom_attributes") _incorporate(data, modifiers, val, mul, div); //Government reforms have some special modifiers. It's easiest to count them as country modifiers.
		if (stringp(val) && sscanf(val, "%[-]%d%*[.]%[0-9]%s", string sign, int whole, string frac, string blank) && blank == "")
			modifiers[id] += (sign == "-" ? -1 : 1) * (whole * 1000 + (int)sprintf("%.03s", frac + "000")) * (mul||1) / (div||1);
		if (intp(val) && val == 1) modifiers[id] = 1; //Boolean
	}
}
mapping estate_definitions = ([]), estate_privilege_definitions = ([]);
mapping(string:int) all_country_modifiers(mapping data, mapping country) {
	if (mapping cached = country->all_country_modifiers) return cached;
	mapping modifiers = ([]);
	//TODO: Add more things here as they get analyzed
	foreach (enumerate_ideas(country->active_idea_groups), mapping idea) _incorporate(data, modifiers, idea);
	foreach (Array.arrayify(country->active_policy), mapping policy)
		_incorporate(data, modifiers, policy_definitions[policy->policy]);
	foreach (Array.arrayify(country->government->reform_stack->reforms), string reform)
		_incorporate(data, modifiers, reform_definitions[reform]);
	foreach (Array.arrayify(country->traded_bonus), string idx)
		_incorporate(data, modifiers, trade_goods[(int)idx]);
	foreach (Array.arrayify(country->modifier), mapping mod)
		_incorporate(data, modifiers, country_modifiers[mod->modifier]);
	mapping age = age_definitions[data->current_age]->abilities;
	_incorporate(data, modifiers, age[Array.arrayify(country->active_age_ability)[*]][*]);
	mapping tech = country->technology || ([]);
	foreach ("adm dip mil" / " ", string cat) {
		int level = (int)tech[cat + "_tech"];
		_incorporate(data, modifiers, tech_definitions[cat]->technology[..level][*]);
		//TODO: If tech_definitions[cat]->technology[level]->year > current year, _incorporate tech_definitions[cat]->ahead_of_time
		//TODO: > or >= ?
	}
	if (array have = country->institutions) foreach (institutions; string id; mapping inst) {
		if (have[inst->_index] == "1") _incorporate(data, modifiers, inst->bonus);
	}
	//More modifier types to incorporate:
	//- Monuments. Might be hard, since they have restrictions. Can we see in the savefile if they're active?
	//- Religious modifiers (icons, cults, aspects, etc)
	//- Government type modifiers (eg march, vassal, colony)

	if (country->luck) _incorporate(data, modifiers, static_modifiers->luck); //Lucky nations (AI-only) get bonuses.
	if (int innov = threeplace(country->innovativeness)) _incorporate(data, modifiers, static_modifiers->innovativeness, innov, 100000);
	if (int corr = threeplace(country->corruption)) _incorporate(data, modifiers, static_modifiers->corruption, corr, 100000);
	//Having gone through all of the above, we should now have estate influence modifiers.
	//Now we can calculate the total influence, and then add in the effects of each estate.
	if (country->estate) {
		//Some estates might not work like this. Not sure.
		//First, incorporate country-wide modifiers from privileges. (It's possible for privs to
		//affect other estates' influences.)
		country->estate = Array.arrayify(country->estate); //In case there's only one estate
		foreach (country->estate, mapping estate) {
			foreach (Array.arrayify(estate->granted_privileges), [string priv, string date]) {
				mapping privilege = estate_privilege_definitions[priv]; if (!privilege) continue;
				_incorporate(data, modifiers, privilege->penalties);
				_incorporate(data, modifiers, privilege->benefits);
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
			_incorporate(data, modifiers, estate_defn["country_modifier_" + opinion], mul, 4);
			estate->estimated_milliinfluence = influence;
		}
	}
	return country->all_country_modifiers = modifiers;
}

mapping(string:int) all_province_modifiers(mapping data, int id) {
	mapping prov = data->provinces["-" + id];
	if (mapping cached = prov->all_province_modifiers) return cached;
	mapping country = data->countries[prov->owner];
	mapping modifiers = ([]);
	if (prov->center_of_trade) {
		string type = province_info[(string)id]->?has_port ? "coastal" : "inland";
		mapping cot = cot_definitions[type + prov->center_of_trade];
		_incorporate(data, modifiers, cot->?province_modifiers);
	}
	if (int l3cot = country->area_has_level3[?prov_area[(string)id]]) {
		string type = province_info[(string)l3cot]->?has_port ? "coastal3" : "inland3";
		mapping cot = cot_definitions[type];
		_incorporate(data, modifiers, cot->?state_modifiers);
	}
	foreach (prov->buildings || ([]); string b;)
		_incorporate(data, modifiers, building_types[b]);
	mapping area = data->map_area_data[prov_area[(string)id]]->?state;
	foreach (Array.arrayify(area->?country_state), mapping state) if (state->country == prov->owner) {
		if (state->prosperity == "100.000") _incorporate(data, modifiers, static_modifiers->prosperity);
		_incorporate(data, modifiers, state_edicts[state->active_edict->?which]);
	}
	_incorporate(data, modifiers, terrain_definitions->categories[province_info[(string)id]->terrain]);
	_incorporate(data, modifiers, static_modifiers[province_info[(string)id]->climate]);
	if (prov->hre) {
		foreach (Array.arrayify(data->empire->passed_reform), string reform)
			_incorporate(data, modifiers, imperial_reforms[reform]->?province);
	}
	_incorporate(data, modifiers, trade_goods[prov->trade_goods]->?province);
	return prov->all_province_modifiers = modifiers;
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
			mapping proj = data->great_projects[project] || (["development_tier": "0"]); //Weirdly, I have once seen a project that's just missing from the file.
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
		//Sometimes the cooldown is still recorded, but is in the past. No idea why. We hide that completely.
		int days; catch {if (date) days = today->distance(calendar(date)) / today;};
		if (!days) {cooldowns += ({({"", "---", "--------", String.capitalize(tradefor), cur})}); continue;}
		cooldowns += ({({"", days, date, String.capitalize(tradefor), cur})}); //TODO: Don't include the initial empty string here, add it for tabulate() only
	}
	if (mappingp(write)) {
		write->monuments = projects[*][-1];
		//Favors are all rendered on the front end.
		mapping owed = ([]);
		foreach (data->countries; string other; mapping c) {
			int favors = threeplace(c->active_relations[tag]->?favors);
			if (favors > 0) owed[other] = ({favors / 1000.0}) + estimate_per_month(data, c)[*] * 6;
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
	mapping country = data->countries[tag];
	array coalprov = ({ });
	foreach (country->owned_provinces, string id) {
		mapping prov = data->provinces["-" + id];
		if (!province_info[id]->has_coal) continue;
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		mapping bldg = prov->buildings || ([]);
		mapping mfg = bldg & manufactories;
		string status = "";
		if (prov->trade_goods != "coal") {
			//Not yet producing coal. There are a few reasons this could be the case.
			if (country->institutions[6] != "1") status = "Not embraced";
			else if (prov->institutions[6] != "100.000") status = "Not Enlightened";
			else if (dev < 20 && (int)country->innovativeness < 20) status = "Need 20 dev/innov";
			else status = "Producing " + prov->trade_goods; //Assuming the above checks are bug-free, the province should flip to coal at the start of the next month.
		}
		else if (bldg->furnace) status = "Has Furnace";
		else if (building_id[(int)prov->building_construction->?building] == "furnace")
			status = prov->building_construction->date;
		else if (sizeof(mfg)) status = values(mfg)[0];
		else if (prov->settlement_growth_construction) status = "SETTLER ACTIVE"; //Can't build while there's a settler promoting growth);
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
		coalprov += ({([
			"id": id, "name": prov->name,
			"status": status, "dev": dev,
			"buildings": buildings, "slots": slots,
		])});
	}
	if (mappingp(write)) {write->coal_provinces = coalprov; return;}
	if (!sizeof(coalprov)) return;
	write("Coal-producing provinces:\n");
	foreach (coalprov, mapping p)
		if (p->status == "") {
			interesting(p->id, PRIO_IMMEDIATE); //TODO: Should it always be highlighted at the same prio? Should it always even be highlighted?
			write("\e[1;%dm%s\t%d/%d bldg\t%d dev\t%s\n", p->buildings < p->slots ? 32 : 36,
				p->id, p->buildings, p->slots, p->dev, string_to_utf8(p->name));
		}
		else write("%s\t%s\t%d dev\t%s\n", p->id, p->status, p->dev, string_to_utf8(p->name));
	write("\n");
}

void analyze_upgrades(mapping data, string name, string tag, function|mapping write) {
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
			if (target && target != constructing) {
				interesting(id, PRIO_SITUATIONAL);
				upgradeables[L10n["building_" + target]] += ({(["id": id, "name": prov->name])}); //Do we need any more info?
			}
		}
	}
	if (mappingp(write)) sort(indices(upgradeables), write->upgradeables = (array)upgradeables); //Sort alphabetically by target building
	else foreach (sort(indices(upgradeables)), string b) {
		write("Can upgrade %d buildings to %s\n", sizeof(upgradeables[b]), b);
		write("==> %s\n", string_to_utf8(upgradeables[b]->name * ", "));
	}
}

void analyze_findbuildings(mapping data, string name, string tag, function|mapping write, string highlight) {
	if (mappingp(write)) write->highlight = (["id": highlight, "name": L10n["building_" + highlight], "provinces": ({ })]);
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
		foreach (prov->buildings || ([]); string b;) {
			if (b == highlight) {gotone = 1; break;}
			while (string upg = building_types[b]->make_obsolete) {
				if (upg == highlight) {gotone = 1; break;}
				b = upg;
			}
			if (gotone) break;
		}
		if (gotone) continue;
		interesting(id, PRIO_EXPLICIT);
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		int need_dev = (dev - dev % 10) + 10 * (buildings - slots + 1);
		if (mappingp(write)) write->highlight->provinces += ({([
			"id": (int)id, "buildings": buildings, "maxbuildings": slots,
			"name": prov->name, "dev": dev, "need_dev": need_dev,
			"cost": calc_province_devel_cost(data, (int)id, need_dev - dev),
		])});
		else write("\e[1;32m%s\t%d/%d bldg\tDev %d\t%s\e[0m\n", id, buildings, slots, dev, string_to_utf8(prov->name));
	}
	if (mappingp(write)) sort(write->highlight->provinces->cost[*][-1], write->highlight->provinces);
}

int(0..1) passes_filter(mapping country, mapping|array filter, int|void any) {
	//If any is 1, then as soon as we find a true return, we propagate it.
	//If any is 0 (ie we need all, the default), we propagate false instead.
	//An empty block - or one containing only types we don't know - will
	//pass an AND check (no restrictions, all fine), but fail an OR check.
	foreach (filter; string kwd; mixed values) {
		//There could be multiple of the same keyword (eg in an OR block, or multiple OR blocks). They're independent.
		foreach (Array.arrayify(values), mixed value) switch (kwd) {
			case "OR": if (passes_filter(country, value, 1) == any) return any;
			default: break; //Unknown type, don't do anything
		}
	}
	return !any;
}

void analyze_obscurities(mapping data, string name, string tag, mapping write) {
	//Gather some more obscure or less-interesting data for the web interface only.
	//It's not worth consuming visual space for these normally, but the client might
	//want to open this up and have a look.

	//Go through your navies and see if any have outdated ships.
	mapping country = data->countries[tag], units = country->sub_unit;
	write->navy_upgrades = ({ });
	foreach (Array.arrayify(country->navy), mapping fleet) {
		mapping composition = ([]);
		int upgrades = 0;
		foreach (Array.arrayify(fleet->ship), mapping ship) {
			string cat = ship_types[ship->type]; //eg heavy_ship, transport
			composition[cat]++;
			//Note that buying or capturing a higher-level unit will show it as upgradeable.
			if (ship->type != units[cat]) {composition[cat + "_upg"]++; upgrades = 1;}
		}
		if (!upgrades) continue;
		string desc = "";
		mapping navy = (["name": fleet->name]);
		foreach ("heavy_ship light_ship galley transport" / " ", string cat)
			navy[cat] = ({composition[cat + "_upg"]||0, composition[cat]||0});
		write->navy_upgrades += ({navy});
	}
	//Enumerate all CBs from and against you, categorized by type
	//TODO: On Conquest CBs, find all provinces with claims and find
	//the last to expire, or a permanent, to show as CB expiration.
	write->cbs = (["from": (["tags": ({ })]), "against": (["tags": ({ })]), "types": ([])]);
	foreach (Array.arrayify(data->diplomacy->casus_belli), mapping cb) {
		if (cb->first != tag && cb->second != tag) continue;
		//if second is tag, put into against
		mapping info = (["tag": cb->first == tag ? cb->second : cb->first]);
		if (cb->end_date) info->end_date = cb->end_date; //Time-limited casus belli
		mapping which = write->cbs[cb->first == tag ? "from" : "against"];
		which[cb->type] += ({info});
		if (!has_value(which->tags, info->tag)) which->tags += ({info->tag});
		if (!write->cbs->types[cb->type]) {
			mapping ty = write->cbs->types[cb->type] = ([
				"name": L10n[cb->type] || cb->type,
				"desc": L10n[cb->type + "_desc"] || cb->type + "_desc",
			]);
			mapping typeinfo = cb_types[cb->type];
			mapping wargoal = wargoal_types[typeinfo->war_goal];
			if (typeinfo->attacker_disabled_po) ty->restricted = "Some peace offers disabled";
			else if (wargoal->allowed_provinces_are_eligible) ty->restricted = "Province selection is restricted";
			foreach (({"badboy", "prestige", "peace_cost"}), string key) ty[key] = (array(float))({
				wargoal->attacker[?key + "_factor"] || wargoal[key + "_factor"],
				wargoal->defender[?key + "_factor"] || wargoal[key + "_factor"],
			});
		}
	}
	//Gather basic country info in a unified format.
	write->countries = map(data->countries) {mapping c = __ARGS__[0];
		if (!c->owned_provinces) return 0;
		mapping capital = data->provinces["-" + c->capital];
		string flag = c->tag;
		if (mapping cust = c->colors->custom_colors) {
			//Custom flags are defined by a symbol and four colours.
			//These are available in the savefile as:
			//cust->symbol_index = emblem
			//cust->flag = background
			//cust->flag_colors = ({color 1, color 2, color 3})
			//(Also, cust->color = map color, fwiw)
			//In each case, the savefile is zero-based, but otherwise, the numbers are
			//the same as can be seen in the nation designer.
			flag = (({"Custom", cust->symbol_index, cust->flag}) + cust->flag_colors) * "-";
		}
		else if (c->colonial_parent) flag = sprintf("%s-%{%02X%}", c->colonial_parent, (array(int))c->colors->country_color);
		return ([
			"name": c->name || L10n[c->tag] || c->tag,
			"tech": ({(int)c->technology->adm_tech, (int)c->technology->dip_tech, (int)c->technology->mil_tech}),
			"province_count": sizeof(Array.arrayify(c->owned_provinces)),
			"capital": c->capital, "capitalname": capital->name,
			"hre": capital->hre, //If the country's capital is in the HRE, the country itself is part of the HRE.
			"development": c->development,
			"institutions": `+(@(array(int))c->institutions),
			"flag": flag,
			"opinion_theirs": c->opinion_cache[country->_index],
			"opinion_yours": country->opinion_cache[c->_index],
			"armies": sizeof(Array.arrayify(c->army)),
			"navies": sizeof(Array.arrayify(c->navy)),
		]);
	};
	write->countries = filter(write->countries) {return __ARGS__[0];}; //Keep only countries that actually have territory
	foreach (Array.arrayify(data->diplomacy->dependency), mapping dep) {
		mapping c = write->countries[dep->second]; if (!c) continue;
		c->overlord = dep->first;
		c->subject_type = L10n[dep->subject_type + "_title"] || dep->subject_type;
		write->countries[dep->first]->subjects++;
	}
	foreach (Array.arrayify(data->diplomacy->alliance), mapping dep) {
		write->countries[dep->first]->alliances++;
		write->countries[dep->second]->alliances++;
	}
	//TODO: Maybe count weaker one-way relationships like guarantees and tributary subjects separately?

	//List countries that could potentially join a coalition
	write->badboy_hatred = ({ });
	foreach (data->countries;; mapping risk) {
		int ae = 0;
		foreach (Array.arrayify(risk->active_relations[tag]->?opinion), mapping opine)
			if (opine->modifier == "aggressive_expansion") ae = -threeplace(opine->current_opinion);
		if (ae < 50000 && risk->coalition_target != tag) continue;
		write->badboy_hatred += ({([
			"tag": risk->tag,
			"badboy": ae,
			"in_coalition": risk->coalition_target == tag,
		])});
	}

	//List truces, grouped by end date
	mapping truces = ([]);
	foreach (data->countries; string other; mapping c) {
		//TODO: Truces view - sort by date, showing blocks of nations that all peaced out together
		//- Can't find actual truce dates, but anti-shenanigans truces seem to set a thing into
		//active_relations[tag]->truce = yes, ->last_war = date when the action happened (truce is
		//five years from then). If there's an actual war, ->last_warscore ranges from 0 to 100?
		mapping rel = c->active_relations[?tag];
		if (!rel->?truce) continue;
		//Instead of getting the truce end date, we get the truce start date and warscore.
		//As warscore ranges from 0 to 100, truce length ranges from 5 to 15 years.
		int truce_months = 60 + 120 - (100 - (int)rel->last_warscore) * 120 / 100; //Double negation to force round-up
		//This could be off by one or two months, but it should be consistent for all
		//countries truced out at once, so they'll remain grouped.
		sscanf(rel->last_war, "%d.%d.%*d", int year, int mon);
		mon += truce_months % 12 + 1; //Always move to the next month
		year += truce_months / 12 + (mon > 12);
		if (mon > 12) mon -= 12;
		string key = sprintf("%04d.%02d", year, mon);
		if (!truces[key]) truces[key] = ({sprintf("%s %d", ("- Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec" / " ")[mon], year)});
		truces[key] += ({({other, ""})}); //TODO: Put info about the war in the second slot?
		if (mapping info = write->countries[other]) info->truce = truces[key][0];
	}
	//Since "annul treaties" has a similar sort of cooldown, and since it can be snuck in
	//when the other party loses very minorly in a war, list those too.
	foreach (Array.arrayify(data->diplomacy->annul_treaties), mapping annulment) {
		string other;
		if (annulment->first == tag) other = annulment->second;
		else if (annulment->second == tag) other = annulment->first;
		else continue;
		//We have the start date; the annulment is always for precisely ten years.
		sscanf(annulment->start_date, "%d.%d.%*d", int year, int mon);
		year += 10;
		//TODO: Should I increment the month to the next one? If you have annul treaties until May 25th,
		//is it more useful to show "May" or "June"?
		string key = sprintf("%04d.%02d", year, mon);
		if (!truces[key]) truces[key] = ({sprintf("%s %d", ("- Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec" / " ")[mon], year)});
		truces[key] += ({({other, "(annul treaties)"})});
	}
	sort(indices(truces), write->truces = values(truces));

	//Previous wars have an "outcome" which isn't always present, but seems to be
	//"2" or "3". Most often 2. I would guess that 2 means victory for attackers,
	//3 victory for defenders, absent means white peace.
	//I'd like to be able to reconstruct the peace treaty, but currently, can't
	//find the necessary info. It might not be saved.
	/*foreach (Array.arrayify(data->previous_war), mapping war) {
		werror("%O [%O/%O] ==> %s\n", war->outcome, war->attacker_score, war->defender_score, war->name);
	}*/

	//Potential colonies, regardless of distance.
	array(mapping) colonization_targets = ({ });
	foreach (data->provinces; string id; mapping prov) {
		if (prov->controller) continue;
		int dev = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
		if (dev < 3) continue; //Sea province, probably
		if (!has_value(prov->discovered_by || ({ }), tag)) continue; //Filter to the ones you're aware of
		array modifiers = map(Array.arrayify(prov->modifier)) { [mapping mod] = __ARGS__;
			if (mod->hidden) return 0;
			array effects = ({ });
			foreach (country_modifiers[mod->modifier] || ([]); string effect; string value) {
				if (effect == "picture") continue; //Would be cool to show the icon in the front end, but whatever
				string desc = upper_case(effect);
				if (effect == "province_trade_power_value") desc = "PROVINCE_TRADE_VALUE"; //Not sure why, but the localisation files write this one differently.
				effects += ({sprintf("%s: %s", L10n[desc] || L10n["MODIFIER_" + desc] || effect, value)});
			}
			return ([
				"name": L10n[mod->modifier],
				"effects": effects,
			]);
		} - ({0});
		mapping provinfo = province_info[id - "-"];
		mapping terraininfo = terrain_definitions->categories[provinfo->terrain] || ([]);
		mapping climateinfo = static_modifiers[provinfo->climate] || ([]);
		colonization_targets += ({([
			"id": id - "-",
			"name": prov->name,
			"cot": (int)prov->center_of_trade,
			"dev": dev,
			"modifiers": modifiers,
			"terrain": provinfo->terrain,
			"climate": provinfo->climate || "temperate", //I *think* the ones with no climate specification are always Temperate??
			"has_port": provinfo->has_port,
			"settler_penalty": -(int)climateinfo->local_colonial_growth,
			//Default sort order: "interestingness"
			"score": (int)id + //Disambiguation
				10000 * (dev + (int)climateinfo->local_colonial_growth + 100 * (int)prov->center_of_trade + 1000 * sizeof(modifiers)),
		])});
		//Is there any way to figure out whether the province is accessible? Anything that has_port
		//is accessible, as is anything adjacent to an existing province - even an unfinished colony,
		//since it will at some point be viable. TODO?
	}
	sort(-colonization_targets->score[*], colonization_targets);
	write->colonization_targets = colonization_targets;

	//Pick up a few possible notifications.
	write->notifications = ({ });
	//Would it be safe to seize land?
	object seizetime = calendar(country->flags->?recent_land_seizure || "1.1.1")->add(Calendar.Gregorian.Year() * 5);
	if (country->estate && seizetime < calendar(data->date)) {
		int ok = 1;
		foreach (country->estate, mapping estate) {
			float threshold = estate->estimated_milliinfluence >= 100000 ? 70.0 : 50.0;
			if ((float)estate->loyalty < threshold) ok = 0;
		}
		//How much crownland do you have? Or rather: how much land do your estates have?
		//If you have 100% crownland, you can't seize. But if you have 99%, you probably
		//don't want to seize, so don't prompt.
		int estateland = `+(0, @threeplace(country->estate->territory[*]));
		if (estateland < 1000) ok = 0;
		if (ok) write->notifications += ({"Estate land seizure is available"});
	}
	if (mapping ag = country->active_agenda) {
		//You have an active agenda.
		write->agenda = ([
			"expiry": ag->expiry_date,
		]);
		//Agendas have different types of highlighting available to them.
		//We support agenda_province and agenda_country modes, but that's
		//all; there are a number of more complicated ones, including:
		//- Any in this area
		//- All in this area
		//- All non-owned in this area
		//- Provinces controlled by rebels
		//We don't support these. Some of them will highlight a province
		//(eg the "area" ones), others won't highlight anything.
		//Proper handling of highlight types would require parsing the estate_agendas
		//files and interpreting the provinces_to_highlight block. These files can now
		//be parsed (see below, commented out), but executing the highlight block is hard.
		foreach (Array.arrayify(ag->scope->?saved_event_target), mapping target) switch (target->name) {
			case "agenda_trade_node": //TODO: Show that it's actually the trade node there??
			case "agenda_province": write->agenda->province = target->province; break;
			case "agenda_country": write->agenda->country = target->country; break;
			case "rival_country": write->agenda->rival_country = target->country; break;
		}
		if (write->agenda->province) write->agenda->province_name = data->provinces["-" + write->agenda->province]->name;
		//If we never find a target of a type we recognize, there's nothing to highlight.
		string desc = L10n[ag->agenda] || ag->agenda;
		//Process some other agenda description placeholders before shooting it through to the front end
		//Most of these are hacks to make it less ugly, because the specific info isn't really interesting.
		desc = replace(desc, ([
			//Trade node names aren't easy to get, and we can't focus on the trade node
			//anyway, so just focus on the (sea) province and name it.
			"[agenda_trade_node.GetTradeNodeName]": "[agenda_province.GetName]",
			//When you need to convert a province, it's obvious which religion to convert to.
			"[Root.Religion.GetName]": "", "[Root.GetReligionNoun]": "",
			//If you have Meritocracy mechanics, yeah, whatever, it's just legitimacy in the description.
			"[Root.GetLegitimacyOrMeritocracy]": "Legitimacy",
			//This might be close enough?
			"[agenda_country.GetAdjective]": "[agenda_country.GetUsableName]",
			"[Root.GetAdjective]": "",
		]));
		//TODO: Actually dig up culture and area names
		//agenda_province.GetAreaName
		//Root.Culture.GetName
		write->agenda->desc = desc;
	}
	else if (country->estate) {
		write->agenda = ([]);
		//Can you summon the diet?
		//This requires (a) no current agenda, (b) at least five years since last diet summoned
		//(note that Supremacy agendas don't block this, though they still count as a current agenda)
		//and (c) you have to not have any of those things that prevent you from summoning, like
		//being England or not having estates.
		object agendatime = calendar(country->flags->?recent_estate_agenda || "1.1.1")->add(Calendar.Gregorian.Year() * 5);
		if (agendatime < calendar(data->date) && sizeof(country->estate) &&
				!country->all_country_modifiers->blocked_call_diet) {
			write->notifications += ({"It's possible to summon the diet"});
		}
	}
	foreach (data->map_area_data; string area; mapping info) {
		foreach (Array.arrayify(info->state->?country_state), mapping state) {
			if (state->country != tag) continue;
			if (!state->active_edict) continue;
			int unnecessary = 1;
			string highlightid = ""; //There should always be at least ONE owned province, otherwise you can't have a state!
			foreach (map_areas[area];; string provid) {
				mapping prov = data->provinces["-" + provid];
				if (prov->owner != tag) continue; //Ignore other people's land in your state
				highlightid = provid;
				switch (state->active_edict->which) {
					case "edict_advancement_effort": {
						//Necessary if any spawned institution is neither embraced by your
						//country nor at 100% in the province
						foreach (data->institutions; int i; string spawned) if (spawned == "1") {
							if (prov->institutions[i] != "100.000" && country->institutions[i] != "1")
								unnecessary = 0;
						}
						break;
					}
					case "edict_centralization_effort": {
						//Necessary when local autonomy is above the autonomy floor.
						//This doesn't reflect the floor, so the edict might become
						//functionally unnecessary before it gets flagged here. Note
						//that this actually ignores fractional autonomy, on the basis
						//that it's not really significant anyway.
						if ((int)prov->local_autonomy) unnecessary = 0;
						break;
					}
					case "edict_feudal_de_jure_law": {
						//Necessary when net unrest is above -5
						//Not sure where unrest is stored. It's probably in separate pieces, like
						//the whiskey wasn't.
						break;
					}
					case "edict_religious_unity": {
						//Necessary if province does not follow state religion
						if (prov->religion != country->religion) unnecessary = 0;
						break;
					}
					default: break; //All other edicts are presumed to be deliberate.
				}
			}
			if (unnecessary) write->notifications += ({({
				"Unnecessary ",
				(["color": textcolors->B * ",", "text": L10n[state->active_edict->which]]),
				" in ",
				(["color": textcolors->B * ",", "text": L10n[area]]),
				(["prov": highlightid, "nameoverride": ""]),
			})});
		}
	}

	write->vital_interest = map(Array.arrayify(country->vital_provinces)) {return ({__ARGS__[0], data->provinces["-" + __ARGS__[0]]->?name || "(unknown)"});};

	//What decisions and missions are open to you, and what provinces should they highlight?
	write->decisions_missions = ({ });
	array completed = country->completed_missions || ({ });
	foreach (Array.arrayify(country->country_missions->?mission_slot), array slot) {
		foreach (slot, string kwd) {
			//Each of these is a mission chain, I think. They're indexed by slot
			//which is 1-5 going across, and each mission has one or two parents
			//that have to be completed. I think that, if there are multiple
			//mission chains in a slot, they are laid out vertically. In any case,
			//we don't really care about layout, just which missions there are.
			mapping mission = country_missions[kwd];
			foreach (mission; string id; mixed info) {
				if (has_value(completed, id)) continue; //Already done this mission, don't highlight it.
				string title = L10n[id + "_title"];
				if (!title) continue; //TODO: What happens if there's a L10n failure?
				//if (!mappingp(info)) {werror("WARNING: Not mapping - %O\n", id); continue;} //FIXME: Parse error on Ottoman_Missions, conquer_serbia, fails this assertion (see icon)
				int prereq = 1;
				if (arrayp(info->required_missions)) foreach (info->required_missions, string req)
					if (!has_value(completed, req)) prereq = 0;
				if (!prereq) continue; //One or more prerequisite missions isn't completed, don't highlight it
				mapping highlight = info->provinces_to_highlight;
				if (!highlight) continue; //Mission does not involve provinces, don't highlight it.
				//Very simplistic filter handling.
				array filters = ({ });
				//TODO: Require that the province not be owned by you *or any non-trib subject*
				if (highlight->NOT->?country_or_non_sovereign_subject_holds == "ROOT")
					filters += ({ lambda(mapping p) {return p->controller != tag;} });
				//Very simplistic search criteria.
				array provs = Array.arrayify(highlight->province_id) + Array.arrayify(highlight->OR->?province_id);
				array areas = Array.arrayify(highlight->area) + Array.arrayify(highlight->OR->?area);
				array interesting = ({ });
				foreach (map_areas[areas[*]] + ({provs}), array|maparray area)
					foreach (area;; string provid) {
						mapping prov = data->provinces["-" + provid];
						int keep = 1;
						foreach (filters, function f) keep = keep && f(prov);
						if (!keep) continue;
						interesting += ({({provid, prov->name})});
					}
				if (sizeof(interesting)) write->decisions_missions += ({([
					"id": id,
					"name": title,
					"provinces": interesting,
				])});
			}
		}
	}
	/* TODO: List decisions as well as missions
	- For the most part, just filter by tag, nothing else. Be aware that there might be
	  "OR = { tag = X tag = Y }", as quite a few decisions are shared.
	- May also need to check "culture_group = iberian" and "primary_culture = basque"
	- Show if major decision
	- provinces_to_highlight
	  - May list a single province_id, an area name, or a region name
	  - May instead have an OR block with zero or more of any of the above
	  - Unsure if "provinces_to_highlight { province_id = 1 area = yemen_area }" would work
	  - Filters are tricky. Look for a few of the most common, ignore the rest.
	    - NOT = { country_or_non_sovereign_subject_holds = ROOT }
	      - ie ignore everything you or a non-tributary subject owns
	    - others?
	*/
	foreach (country_decisions; string kwd; mapping info) {
		//TODO.
		if (!passes_filter(country, info->potential)) continue;
		//werror("%s -> %s %O\n", tag, kwd, info->potential);
	}

	//Get some info about provinces, for the sake of the province details view
	write->province_info = (mapping)map((array)data->provinces) {[[string id, mapping prov]] = __ARGS__;
		return ({id - "-", ([
			"discovered": has_value(Array.arrayify(prov->discovered_by), tag),
			"controller": prov->controller, "owner": prov->owner,
			"name": prov->name,
			"wet": terrain_definitions->categories[province_info[id - "-"]->?terrain]->?is_water,
			"terrain": province_info[id - "-"]->?terrain,
			"climate": province_info[id - "-"]->?climate,
			//"raw": prov,
		])});
	};
}

mapping(string:array) interesting_provinces = ([]);
void analyze(mapping data, string name, string tag, function|mapping|void write, string|void highlight) {
	if (!write) write = Stdio.stdin->write;
	interesting_province = ({ }); interest_priority = 0;
	if (mappingp(write)) write->name = name + " (" + (data->countries[tag]->name || L10n[tag] || tag) + ")";
	else write("\e[1m== Player: %s (%s) ==\e[0m\n", name, tag);
	({analyze_cot, analyze_leviathans, analyze_furnace, analyze_upgrades})(data, name, tag, write);
	if (mappingp(write)) analyze_obscurities(data, name, tag, write);
	if (highlight) analyze_findbuildings(data, name, tag, write, highlight);
	//write("* %s * %s\n\n", tag, Standards.JSON.encode((array(int))interesting_province)); //If needed in a machine-readable format
	interesting_provinces[tag] = interesting_province;
}

array(int) calc_province_devel_cost(mapping data, int id, int|void improvements) {
	mapping prov = data->provinces["-" + id];
	mapping country = data->countries[prov->owner];
	if (!country) return ({50, 0, 0, 50 * (improvements||1)}); //Not owned? Probably not meaningful, just return base values.
	mapping mods = all_country_modifiers(data, country);
	//Development efficiency from admin tech affects the base cost multiplicatively before everything else.
	int base_cost = 50 * (1000 - mods->development_efficiency) / 1000;

	mapping localmods = all_province_modifiers(data, id);
	int cost_factor = mods->development_cost + localmods->local_development_cost + mods->all_power_cost;

	//As the province gains development, the cost goes up.
	int devel = (int)prov->base_tax + (int)prov->base_production + (int)prov->base_manpower;
	int devcost = 0;
	//Add 3% for every development above 9, add a further 3% for every devel above 19, another above 29, etc.
	for (int thr = 9; thr < devel; thr += 10) devcost += 30 * (devel - thr);

	int final_cost = base_cost * (1000 + cost_factor + devcost) / 1000;
	//If you asked for more than one improvement, calculate the total cost.
	for (int i = 1; i < improvements; ++i) {
		++devel;
		devcost += devel / 10;
		final_cost += base_cost * (1000 + cost_factor + devcost) / 1000;
	}
	//NOTE: Some of these factors won't be quite right. For instance, Burghers influence
	//is not perfectly calculated, so if it goes above or below a threshold, that can
	//affect the resulting costs. Hopefully that will always apply globally, so the
	//relative effects of province choice will still be meaningful. (This will skew things
	//somewhat based on the number of improvements required though.)
	return ({base_cost, cost_factor, devcost, final_cost});
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
					tag, fleet->name,
					L10n[ship->type], ship->name,
					L10n[ship->flagship->modification[*]],
					ship->flagship->is_captured ? (data->countries[was]->name || L10n[was] || was) : ""
				})});
				else flagships += ({({
					string_to_utf8(sprintf("\e[1m%s\e[0m - %s: \e[36m%s %q\e[31m%s\e[0m",
						country->name || L10n[tag] || tag, fleet->name,
						L10n[ship->type], ship->name, cap)),
					//Measure size without colour codes or UTF-8 encoding
					sizeof(sprintf("%s - %s: %s %q%s",
						country->name || L10n[tag] || tag, fleet->name,
						L10n[ship->type], ship->name, cap)),
					L10n[ship->flagship->modification[*]] * ", ",
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
					mappingp(write) ? p->tag : country->name || L10n[p->tag] || p->tag,
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
					mappingp(write) ? p->tag : country->name || L10n[p->tag] || p->tag,
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
		string id;
		if (!provincecycle[country]) {
			string tag = find_country(last_parsed_savefile, country); if (!tag) return;
			if (!interesting_provinces[tag]) analyze(last_parsed_savefile, "Province finder", tag); //Should this be sent to /dev/null instead of the console?
			if (!sizeof(interesting_provinces[tag])) {sock->close("w"); return;}
			[id, array rest] = Array.shift(interesting_provinces[tag]);
			interesting_provinces[tag] = rest + ({id});
		}
		else {
			[id, array rest] = Array.shift(provincecycle[country]);
			provincecycle[country] = rest + ({id});
		}
		//Note: Ignores buffered mode and writes directly. I don't think it's possible to
		//put a "shutdown write direction when done" marker into the Buffer.
		sock->write("provfocus " + id + "\nexit\n");
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
void done_processing_savefile(object pipe, string msg) {
	msg += parser_pipe->read() || ""; //Purge any spare text
	//TODO: Deduplicate parsing definition with the main update handler
	if (has_value(msg, '+')) {++parsing; send_update(`+(({ }), @values(websocket_groups)), (["parsing": parsing && (parsing - 1) * 100 / PARSE_PROGRESS_FRACTION]));}
	if (!has_value(msg, '*')) return;
	mapping data = Standards.JSON.decode_utf8(Stdio.read_file("eu4_parse.json") || "{}")->data;
	if (!data) {werror("Unable to parse save file (see above for errors, hopefully)\n"); return;}
	write("\nCurrent date: %s\n", data->date);
	foreach (data->players_countries / 2, [string name, string tag]) analyze(data, name, tag);
	analyze_wars(data, (multiset)(data->players_countries / 2)[*][1]);
	indices(connections[""])->inform(data);
	provincecycle = ([]);
	last_parsed_savefile = data;
	parsing = 0; send_updates_all();
}

class ClientConnection {
	inherit Connection;
	inherit Concurrent.Promise;
	protected void create(Stdio.File sock) {
		Connection::create(sock);
		Promise::create();
		Stdio.stdin->set_read_callback(stdinread);
		Stdio.stdin->set_close_callback(stdineof);
	}
	int keysend_provid;
	mixed keysend_callout;
	int terminate = 0;
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
		if (terminate) exit(0);
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
			if (ret[0] == "exit") terminate = 1;
		}
	}
	void sockclosed() {
		::sockclosed();
		success(1 + terminate);
	}
	void stdinread(mixed _, string data) {sock->write(data);}
	void stdineof() {sock->close("w");}
}

void establish_client_connection(string ip, string cmd, int reconnect) {
	Stdio.File sock = Stdio.File();
	string writeme;
	while (1) {
		writeme = sock->connect(ip, 1444, cmd + "\n");
		if (writeme || !reconnect) break;
		sleep(10);
	}
	if (!writeme) exit(0, "Unable to connect to %s : 1444\n", ip);
	sock->write(writeme); //TBH there shouldn't be any residual data, since it should be a single packet.
	object conn = ClientConnection(sock);
	conn->then() {if (__ARGS__[0] != 2) {
		if (reconnect) call_out(establish_client_connection, 10, ip, cmd, reconnect);
		else exit(0);
	}};
	//Single-report goto-province mode is currently broken.
}

class PipeConnection {
	inherit Connection;
	void sockread() {
		progress_pipe = sock;
		while (array ret = incoming->sscanf("%s\n")) {
			[string fn] = ret;
			string raw = Stdio.read_file(fn); //Assumes ISO-8859-1, which I think is correct
			if (parse_savefile(raw, basename(fn))) sock->write("*"); //Signal the parent. It can read it back from the cache.
		}
	}
}

mapping(string:Image.Image) image_cache = ([]);
mapping custom_country_colors;
Image.Image|array(Image.Image|int) load_image(string fn, int|void withhash) {
	if (!image_cache[fn]) {
		string raw = Stdio.read_file(fn);
		if (!raw) return withhash ? ({0, 0}) : 0;
		sscanf(Crypto.SHA1.hash(raw), "%20c", int hash);
		function decoder = Image.ANY.decode;
		if (has_suffix(fn, ".tga")) decoder = Image.TGA.decode; //Automatic detection doesn't pick these properly.
		if (has_prefix(raw, "DDS")) {
			//Custom flag symbols, unfortunately, come from a MS DirectDraw file. Pike's image
			//library can't read this format, so we have to get help from ImageMagick.
			mapping rc = Process.run(({"convert", fn, "png:-"}));
			//assert rc=0, stderr=""
			raw = rc->stdout;
			decoder = Image.PNG._decode; //HACK: This actually returns a mapping, not just an image.
		}
		if (catch {image_cache[fn] = ({decoder(raw), hash});}) {
			//Try again via ImageMagick.
			mapping rc = Process.run(({"convert", fn, "png:-"}));
			image_cache[fn] = ({Image.PNG.decode(rc->stdout), hash});
		}
	}
	if (withhash) return image_cache[fn];
	else return image_cache[fn][0];
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
", Protocols.HTTP.uri_decode(tag || "?!?")),
	]);
	if (sscanf(req->not_query, "/flags/%[A-Z_a-z]%[-0-9A-F].%s", string tag, string color, string ext) && tag != "" && ext == "png") {
		//Generate a country flag in PNG format
		string etag; Image.Image img;
		if (tag == "Custom") {
			//Custom nation flags are defined by a symbol and four colours.
			sscanf(color, "-%d-%d-%d-%d-%d", int symbol, int flag, int color1, int color2, int color3);
			//If flag (the "Background" in the UI) is 0-33 (1-34 in the UI), it is a two-color
			//flag defined in gfx/custom_flags/pattern.tga, which is a spritesheet of 128x128
			//sections, ten per row, four rows. Replace red with color1, green with color2.
			//If it is 34-53 (35-54 in the UI), it is a three-color flag from pattern2.tga,
			//also ten per row, two rows, also 128x128. Replace blue with color3.
			//(Some of this could be parsed out of custom_country_colors. Hardcoded for now.)
			[Image.Image backgrounds, int bghash] = load_image(PROGRAM_PATH + "/gfx/custom_flags/pattern" + "2" * (flag >= 34) + ".tga", 1);
			//NOTE: Symbols for custom nations are drawn from a pool of 120, of which client states
			//are also selected, but restricted by religious group. (Actually there seem to be 121 on
			//the spritesheet, but the last one isn't available to customs.)
			//The symbol spritesheet is 4 rows of 32, each 64x64. It might be possible to find
			//this info in the edit files somewhere, but for now I'm hard-coding it.
			[mapping symbols, int symhash] = load_image(PROGRAM_PATH + "/gfx/interface/client_state_symbols_large.dds", 1);
			//Note that if the definitions of the colors change but the spritesheets don't,
			//we'll generate the exact same etag. Seems unlikely, and not that big a deal anyway.
			etag = sprintf("W/\"%x-%x-%d-%d-%d-%d-%d\"", bghash, symhash, symbol, flag, color1, color2, color3);
			if (has_value(req->request_headers["if-none-match"] || "", etag)) return (["error": 304]); //Already in cache
			if (flag >= 34) flag -= 34; //Second sheet of patterns
			int bgx = 128 * (flag % 10), bgy = 128 * (flag / 10);
			int symx = 64 * (symbol % 32), symy = 64 * (symbol / 32);
			img = backgrounds->copy(bgx, bgy, bgx + 127, bgy + 127)
				->change_color(255, 0, 0, @(array(int))custom_country_colors->flag_color[color1])
				->change_color(0, 255, 0, @(array(int))custom_country_colors->flag_color[color2])
				->change_color(0, 0, 255, @(array(int))custom_country_colors->flag_color[color3])
				->paste_mask(
					symbols->image->copy(symx, symy, symx + 63, symy + 63),
					symbols->alpha->copy(symx, symy, symx + 63, symy + 63),
				32, 32);
		}
		else {
			//Standard flags are loaded as-is.
			[img, int hash] = load_image(PROGRAM_PATH + "/gfx/flags/" + tag + ".tga", 1);
			if (!img) return 0;
			//For colonial nations, instead of using the country's own tag (eg C03), we get
			//a flag definition based on the parent country and a colour.
			if (!color || sizeof(color) != 7 || color[0] != '-') color = "";
			//NOTE: Using weak etags since the result will be semantically identical, but
			//might not be byte-for-byte (since the conversion to PNG might change it).
			etag = sprintf("W/\"%x%s\"", hash, color);
			if (has_value(req->request_headers["if-none-match"] || "", etag)) return (["error": 304]); //Already in cache
			if (sscanf(color, "-%2x%2x%2x", int r, int g, int b))
				img = img->copy()->box(img->xsize() / 2, 0, img->xsize(), img->ysize(), r, g, b);
		}
		//TODO: Mask flags off with shield_mask.tga or shield_fancy_mask.tga or small_shield_mask.tga
		//I'm using 128x128 everywhere, but the fancy mask (the largest) is only 92x92. For inline
		//flags in text, small_shield_mask is the perfect 24x24.
		return ([
			"type": "image/png", "data": Image.PNG.encode(img),
			"extra_heads": (["ETag": etag, "Cache-Control": "max-age=604800"]),
		]);
	}
}
constant NOT_FOUND = (["error": 404, "type": "text/plain", "data": "Not found"]);
void http_handler(Protocols.HTTP.Server.Request req) {req->response_and_finish(respond(req) || NOT_FOUND);}

//Persisted prefs, keyed by country tag or player name. They apply to all connections for that user (to prevent inexplicable loss of config on dc).
mapping(string:mapping(string:mixed)) tag_preferences = ([]);
//tag_preferences->Rosuav ==> prefs for Rosuav, regardless of country
//tag_preferences->CAS ==> prefs for Castille, regardless of player
//...->highlight_interesting == building ID highlighted for further construction
//...->group_selection == slash-delimited path to the group of provinces to cycle through
//...->cycle_province_ids == array of (string) IDs to cycle through; if absent or empty, use default algorithm
//...->pinned_provinces == mapping of (string) IDs to sequential numbers
//...->search == current search term
mapping(string:array(string)) provincecycle = ([]); //Not saved into preferences. Calculated from tag_preferences[group]->cyclegroup and the save file.
mapping persist_path(string ... parts)
{
	mapping ret = tag_preferences;
	foreach (parts, string idx)
	{
		if (undefinedp(ret[idx])) ret[idx] = ([]);
		ret = ret[idx];
	}
	return ret;
}
void persist_save() {Stdio.write_file(".eu4_preferences.json", Standards.JSON.encode((["tag_preferences": tag_preferences]), 7));}

void websocket_cmd_highlight(mapping conn, mapping data) {
	mapping prefs = persist_path(conn->group);
	if (!building_types[data->building]) m_delete(prefs, "highlight_interesting");
	else prefs->highlight_interesting = data->building;
	persist_save(); update_group(conn->group);
}

void websocket_cmd_goto(mapping conn, mapping data) {
	indices(connections["province"])->provnotify(data->tag, (int)data->province);
}

void websocket_cmd_pin(mapping conn, mapping data) {
	mapping pins = persist_path(conn->group, "pinned_provinces");
	if (pins[data->province]) m_delete(pins, data->province);
	else if (last_parsed_savefile->provinces["-" + data->province]) pins[data->province] = max(@values(pins)) + 1;
	persist_save(); update_group(conn->group);
}

void websocket_cmd_cyclegroup(mapping conn, mapping data) {
	mapping prefs = persist_path(conn->group);
	if (!data->cyclegroup || data->cyclegroup == "") m_delete(prefs, "cyclegroup");
	else prefs->cyclegroup = data->cyclegroup;
	m_delete(provincecycle, conn->group);
	persist_save(); update_group(conn->group);
}

void websocket_cmd_cycleprovinces(mapping conn, mapping data) {
	mapping prefs = persist_path(conn->group);
	if (!prefs->cyclegroup || !arrayp(data->provinces)) m_delete(provincecycle, conn->group);
	else provincecycle[conn->group] = (array(string))(array(int))data->provinces - ({"0"});
	persist_save(); update_group(conn->group);
}

void websocket_cmd_search(mapping conn, mapping data) {
	mapping prefs = persist_path(conn->group);
	prefs->search = stringp(data->term) ? lower_case(data->term) : "";
	persist_save(); update_group(conn->group);
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
		//The group is a country tag or player name as a string.
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
	string resp = Standards.JSON.encode((["cmd": "update"]) | state, 4);
	foreach (socks, object sock)
		if (sock && sock->state == 1) sock->send_text(resp);
}

void update_group(string tag) {send_update(websocket_groups[tag], get_state(tag) | (["parsing": parsing && (parsing - 1) * 100 / PARSE_PROGRESS_FRACTION]));}
void send_updates_all() {foreach (websocket_groups; string tag;) update_group(tag);}

/* Peace treaty analysis

A peace treaty found in game.log begins with a date, eg "20 November 1445".
If this was the final peace treaty (between war leaders), then data->previous_war will contain an entry
that has its final history block carrying the same date ("1445.11.20").
If it's a separate peace and the war is still ongoing in the current savefile, then data->active_war
will contain an entry with a history block for the same date, stating that the attacker or defender
was removed from the war.
If it was a separate peace, but the entire war has closed out before the savefile happened, then the
same war entry will be in data->previous_war.

To check:
1) In a non-final history entry, is it possible to get rem_attacker and rem_defender with the same date? It
   would require a separate peace each direction while the game is paused. Get Stephen to help test.
   (To test, declare war on each other, both with allies. Drag out the war, don't accept any peace terms,
   until allies on both sides are willing to white peace. White peace one ally out. Can the *opposite* war
   leader send a peace treaty? The same one can't. Keep war going until next save, or just save immediately.)
   - Yes. It is absolutely possible to send peace treaties both directions on the same day. They show up in
     the file as separate blocks with the same key, which the parser will combine. You can't get two blocks
     with rem_attacker or two with rem_defender, but you CAN have one of each getting merged.
2) When a country is annexed, does their entry remain, with the same country_name visible? We get tags in the
   save file, but names in the summary ("Yas have accepted peace with Hormuz").
3) Does a country always have a truce entry for that war? Check odd edge cases. Normally, if rem_attacker,
   look for original_defender, and vice versa; self->active_relations[original_other] should have entries.
4) What is last_war_status?
*/

array recent_peace_treaties = ({ }); //Recent peace treaties only, but hopefully useful
mapping get_state(string group) {
	mapping data = last_parsed_savefile; //Get a local reference in case it changes while we're processing
	if (!data) return (["error": "Processing savefile... "]);
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
	mapping ret = (["tag": tag, "self": data->countries[tag], "highlight": ([]), "recent_peace_treaties": recent_peace_treaties]);
	analyze(data, group, tag, ret, persist_path(group)->highlight_interesting);
	multiset players = (multiset)(data->players_countries / 2)[*][1]; //Normally, show all wars involving players.
	if (!players[tag]) players = (<tag>); //But if you switch to a non-player country, show that country's wars instead.
	analyze_wars(data, players, ret);
	analyze_flagships(data, ret);
	//Enumerate available building types for highlighting. TODO: Check if some changes here need to be backported to the console interface.
	mapping available = ([]);
	mapping tech = country->technology;
	int have_mfg = 0;
	foreach (building_types; string id; mapping bldg) {
		[string techtype, int techlevel] = bldg->tech_required || ({"", 100}); //Ignore anything that's not a regular building
		if ((int)tech[techtype] < techlevel) continue; //Hide IDs you don't have the tech to build
		if (bldg->manufactory && !bldg->show_separate) {have_mfg = 1; continue;} //Collect regular manufactories under one name
		if (bldg->influencing_fort) continue; //You won't want to check forts this way
		available[id] = ([
			"id": id, "name": L10n["building_" + id],
			"cost": bldg->manufactory ? 500 : (int)bldg->cost,
			"raw": bldg,
		]);
	}
	//Restrict to only those buildings for which you don't have an upgrade available
	foreach (indices(available), string id) if (available[building_types[id]->obsoleted_by]) m_delete(available, id);
	if (have_mfg) available->manufactory = ([ //Note that building_types->manufactory is technically valid
		"id": "manufactory", "name": "Manufactory (standard)",
		"cost": 500,
	]);
	array bldg = values(available); sort(indices(available), bldg);
	ret->buildings_available = bldg;
	mapping prefs = persist_path(group);
	mapping pp = prefs->pinned_provinces || ([]);
	array ids = indices(pp); sort(values(pp), ids);
	ret->pinned_provinces = map(ids) {return ({__ARGS__[0], data->provinces["-" + __ARGS__[0]]->?name || "(unknown)"});};
	if (prefs->cyclegroup) {ret->cyclegroup = prefs->cyclegroup; ret->cycleprovinces = provincecycle[group];}

	string term = prefs->search;
	array results = ({ }), order = ({ });
	if (term != "") {
		foreach (sort(indices(data->provinces)), string id) { //Sort by ID for consistency
			mapping prov = data->provinces[id];
			foreach (({({prov->name, ""})}) + (province_localised_names[id - "-"]||({ })), [string|array(string) tryme, string lang]) {
				//I think this is sometimes getting an array of localised names
				//(possibly including a capital name??). Should we pick one, or
				//search all?
				if (arrayp(tryme)) tryme = tryme[0];
				string folded = lower_case(tryme); //TODO: Fold to ASCII for the search
				int pos = search(folded, term);
				if (pos == -1) continue;
				int end = pos + sizeof(term);
				string before = tryme[..pos-1], match = tryme[pos..end-1], after = tryme[end..];
				if (lang != "") {before = prov->name + " (" + lang + ": " + before; after += ")";}
				results += ({({(int)(id - "-"), before, match, after})});
				order += ({folded}); //Is it better to sort by the folded or by the tryme?
				break;
			}
			if (sizeof(results) >= 25) break;
		}
		if (sizeof(results) < 25) foreach (sort(indices(ret->countries)), string t) {
			string tryme = ret->countries[t]->name + " (" + t + ")";
			string folded = lower_case(tryme); //TODO: As above. Also, dedup if possible.
			int pos = search(folded, term);
			if (pos == -1) continue;
			int end = pos + sizeof(term);
			string before = tryme[..pos-1], match = tryme[pos..end-1], after = tryme[end..];
			results += ({({t, before, match, after})});
			order += ({folded});
			if (sizeof(results) >= 25) break;
		}
	}
	sort(order, results); //Sort by name for the actual results. So if it's truncated to 25, it'll be the first 25 by (string)id, but they'll be in name order.
	ret->search = (["term": term, "results": results]);

	//Scan all provinces for whether you've discovered them or not
	//Deprecated in favour of the province_info[] mapping
	mapping discov = ret->discovered_provinces = ([]);
	foreach (data->provinces; string id; mapping prov) if (has_value(Array.arrayify(prov->discovered_by), tag)) discov[id - "-"] = 1;

	return ret;
}

mapping(string:array|string|object) icons = ([]);
array|string text_with_icons(string text) {
	//Note: This assumes the log file is ISO-8859-1. (It does always seem to be.)
	//Parse out icons like "\xA3dip" into image references
	text = replace(text, "\xA4", "\xA3icon_gold\xA3"); //\xA4 is a shorthand for the "ducats" icon
	array ret = ({ });
	while (sscanf(text, "%s\xA3%s%[ .,()\xA3]%s", string plain, string icon, string end, text) == 4) {
		//For some reason, %1[...] doesn't do what I want.
		sscanf(end, "%1s%s", end, string trail); text = trail + text;
		//The icon marker ends with either another \xA3 or some punctuation. If it's punctuation, retain it.
		if (end != "\xA3") text = end + text;
		string key;
		//TODO: If we find multiple arrays of filenames, join them together
		foreach (({"GFX_text_" + icon, "GFX_" + icon}), string tryme) if (icons[tryme]) {key = tryme; break;}
		array|string img = key ? icons[key] : "data:image/borked,unknown_key";
		if (arrayp(img)) {
			//Some icons have multiple files. Try each one in turn until one succeeds.
			//Hack: Some are listed with TGA files, but actually have DDSes provided.
			//So we ignore the suffix and just try both.
			array allfn = ({ });
			foreach (img, string fn) allfn += ({fn, replace(fn, ".dds", ".tga"), replace(fn, ".tga", ".dds")});
			img = Array.uniq(allfn);
			foreach (img, string fn) {
				object|mapping png = load_image(PROGRAM_PATH + "/" + fn);
				if (mappingp(png)) png = png->image;
				if (!png) continue;
				img = "data:image/png;base64," + MIME.encode_base64(Image.PNG.encode(png), 1);
				break;
			}
			if (arrayp(img)) img = "data:image/borked," + img * ","; //Hopefully browsers will know that they can't render this
			icons["GFX_text_" + icon] = img;
		}
		ret += ({plain, (["icon": img, "title": icon])});
	}
	if (!sizeof(ret)) return text;
	return ret + ({text});
}

mapping textcolors;
array parse_text_markers(string line) {
	//Parse out colour codes and other markers
	array info = ({ });
	while (sscanf(line, "%s\xA7%1s%s", string txt, string code, line) == 3) {
		if (txt != "") info += ({text_with_icons(txt)});
		//"\xA7!" means reset, and "\xA7W" means white, which seems to be used
		//as a reset. Ignore them both and just return the text as-is.
		if (code == "!" || code == "W") continue;
		array(string) color = textcolors[code];
		if (!color) {
			info += ({(["abbr": "<COLOR>", "title": "Unknown color code (" + code + ")"])});
			continue;
		}
		//Sometimes color codes daisy-chain into each other. We prefer to treat them as containers though.
		sscanf(line, "%s\xA7%s", line, string next);
		info += ({(["color": color * ",", "text": text_with_icons(line)])});
		if (next) line = "\xA7" + next; else line = "";
	}
	return info + ({text_with_icons(line)});
}

constant ICON_REPRESENTATIONS = ([
	"dip": "\U0001F54A\uFE0F", //Diplomacy is for the birds
]);

string render_text(array|string|mapping txt) {
	//Inverse of parse_text_markers: convert the stream into ANSI escape sequences.
	if (stringp(txt)) return txt;
	if (arrayp(txt)) return render_text(txt[*]) * "";
	if (txt->color) return sprintf("\e[38;2;%sm%s\e[0m", replace(txt->color, ",", ";"), render_text(txt->text));
	if (txt->abbr) return txt->abbr; //Ignore the hover (if there's no easy way to put it)
	if (txt->icon) return ICON_REPRESENTATIONS[txt->title] || "[" + txt->title + "]";
	return "<ERROR>";
}

void watch_game_log(object inot) {
	//Monitor the log, and every time there's a new line that matches "[messagehandler.cpp:351]: ... accepted peace ...",
	//add it to a list of peace treaties. When the log is truncated or replaced, clear that list.
	string logfn = SAVE_PATH + "/../logs/game.log";
	object log = Stdio.File(logfn);
	log->set_nonblocking();
	string data = "";
	void parse() {
		data += log->read();
		while (sscanf(data, "%s\n%s", string line, data)) {
			line = String.trim(line);
			if (!sscanf(line, "[messagehandler.cpp:%*d]: %s", line)) continue;
			if (has_value(line, "accepted peace")) { //TODO: Make sure this filters out any that don't belong, like some event choices
				//TODO: Tag something so that, the next time we see a save file, we augment the
				//peace info with the participants, the peace treaty value (based on truce length),
				//and the name of the war. Should be possible to match on the date (beginning of line).
				recent_peace_treaties = ({parse_text_markers(line)}) + recent_peace_treaties;
				write("\e[1mPEACE:\e[0m %s\n", string_to_utf8(render_text(recent_peace_treaties[0])));
				string msg = Standards.JSON.encode((["cmd": "update", "recent_peace_treaties": recent_peace_treaties]));
				foreach (websocket_groups;; array socks)
					foreach (socks, object sock)
						if (sock && sock->state == 1) sock->send_text(msg);
			}
		}
	}
	parse();
	int pos = log->tell();
	inot->add_watch(logfn, System.Inotify.IN_MODIFY) {
		[int event, int cookie, string path] = __ARGS__;
		if (file_stat(logfn)->size < pos) {
			//File seems to have been truncated. Note that this won't catch
			//deleting the file and creating a new one.
			log->seek(0);
			recent_peace_treaties = ({ });
		}
		parse();
		pos = log->tell();
	};
	//If we need to handle deletes/recreations or file movements, watch the directory too.
	/*inot->add_watch(SAVE_PATH + "/../logs", System.Inotify.IN_CREATE | System.Inotify.IN_MOVED_TO) {
		[int event, int cookie, string path] = __ARGS__;
		write("Got a dir event! %O %O %O\n", event, cookie, path); //Moved is 128, create is 256
	};*/
}

int main(int argc, array(string) argv) {
	if (argc > 1 && argv[1] == "--parse") {
		//Parser subprocess, invoked by parent for asynchronous parsing.
		PipeConnection(Stdio.File(3)); //We should have been given fd 3 as a pipe
		return -1;
	}
	if (argc > 1 && argv[1] == "--timeparse") {
		string fn = argc > 2 ? argv[2] : "mp_autosave.eu4";
		object start = System.Timer();
		#define TIME(x) {float tm = gauge {x;}; write("%.3f\t%.3f\t%s\n", start->get(), tm, #x);}
		string raw; TIME(raw = Stdio.read_file(SAVE_PATH + "/" + fn));
		mapping data; TIME(data = parse_savefile_string(raw));
		write("Parse successful. Date: %s\n", data->date);
		return 0;
	}
	if (argc > 2) {
		//First arg is server name/IP; the rest are joined and sent as a command.
		//If the second arg is "province", then the result is fed as keys to EU4.
		//Otherwise, this is basically like netcat/telnet.
		//If --reconnect, will auto-retry until connection succeeds, ten-second
		//retry delay. Will also reconnect after disconnection.
		int reconnect = has_value(argv, "--reconnect"); argv -= ({"--reconnect"});
		establish_client_connection(argv[1], argv[2..] * " ", reconnect);
		return -1;
	}

	//Load up some info that is presumed to not change. If you're modding the game, this may break.
	mapping gfx = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/interface/core.gfx"));
	//There might be multiple bitmapfonts entries. Logically, I think they should just be merged? Not sure.
	//It seems that only one of them has the textcolors block that we need.
	array|mapping tc = gfx->bitmapfonts->textcolors;
	if (arrayp(tc)) textcolors = (tc - ({0}))[0]; else textcolors = tc;
	foreach (sort(glob("*.gfx", get_dir(PROGRAM_PATH + "/interface"))), string fn) {
		string raw = Stdio.read_file(PROGRAM_PATH + "/interface/" + fn);
		//HACK: One of the files has a weird loose semicolon in it! Comment character? Unnecessary separator?
		raw = replace(raw, ";", "");
		mapping data = low_parse_savefile(raw);
		array sprites = data->?spriteTypes->?spriteType;
		if (sprites) foreach (Array.arrayify(sprites), mapping sprite)
			icons[sprite->name] += ({sprite->texturefile});
	}
	catch {L10n = Standards.JSON.decode_utf8(Stdio.read_file(".eu4_localisation.json"));};
	if (!mappingp(L10n)) {
		L10n = ([]);
		foreach (glob("*_l_english.yml", get_dir(PROGRAM_PATH + "/localisation")), string fn)
			parse_localisation(Stdio.read_file(PROGRAM_PATH + "/localisation/" + fn));
		Stdio.write_file(".eu4_localisation.json", Standards.JSON.encode(L10n, 1));
	}
	map_areas = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/map/area.txt"));
	foreach (map_areas; string areaname; array|maparray provinces)
		foreach (provinces;; string id) prov_area[id] = areaname;
	terrain_definitions = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/map/terrain.txt"));
	mapping climates = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/map/climate.txt"));
	//Terrain and climate info are used below.
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
	tech_definitions = ([]);
	foreach (({"adm", "dip", "mil"}), string cat) {
		mapping tech = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/technologies/" + cat + ".txt"));
		tech_definitions[cat] = tech_definitions[cat + "_tech"] = tech;
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
	mapping cat_ideas = ([]);
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
		//tidied->category = group->category; //useful?
		tidied->ideas = basic_ideas;
		idea_definitions[grp] = tidied;
		if (group->category) cat_ideas[group->category] += ({grp});
	}
	policy_definitions = parse_config_dir(PROGRAM_PATH + "/common/policies");
	/*mapping policies = ([]);
	foreach (policy_definitions; string id; mapping info) {
		array ideas = info->allow->?full_idea_group; if (!ideas) continue;
		string cat = info->monarch_power; //Category of the policy. Usually will be one of the idea groups' categories.
		array cats = idea_definitions[ideas[*]]->category;
		sort(cats, ideas);
		if (!policies[ideas[0]]) policies[ideas[0]] = ([]);
		policies[ideas[0]][ideas[1]] = cat;
	}
	mapping counts = ([]);
	foreach (cat_ideas->ADM, string adm) {
		foreach (cat_ideas->DIP, string dip) {
			foreach (cat_ideas->MIL, string mil) {
				string cats = sort(({policies[adm][dip], policies[adm][mil], policies[dip][mil]})) * " ";
				//werror("%s %s %s -> %s\n", adm, dip, mil, cats);
				counts[cats] += ({sprintf("%s %s %s", adm - "_ideas", dip - "_ideas", mil - "_ideas")});
			}
		}
	}
	exit(0, "%O\n", counts);*/
	estate_definitions = parse_config_dir(PROGRAM_PATH + "/common/estates");
	estate_privilege_definitions = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/estate_privileges/00_privileges.txt"));
	reform_definitions = parse_config_dir(PROGRAM_PATH + "/common/government_reforms");
	static_modifiers = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/static_modifiers/00_static_modifiers.txt"));
	retain_map_indices = 1;
	trade_goods = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/tradegoods/00_tradegoods.txt"));
	institutions = parse_config_dir(PROGRAM_PATH + "/common/institutions");
	retain_map_indices = 0;
	foreach (trade_goods; string id; mapping info) {
		trade_goods[info->_index + 1] = info;
		info->id = id;
	}
	country_modifiers = parse_config_dir(PROGRAM_PATH + "/common/event_modifiers")
		| parse_config_dir(PROGRAM_PATH + "/common/parliament_issues");
	age_definitions = parse_config_dir(PROGRAM_PATH + "/common/ages");
	mapping cot_raw = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/centers_of_trade/00_centers_of_trade.txt"));
	cot_definitions = ([]);
	foreach (cot_raw; string id; mapping info) {
		cot_definitions[info->type + info->level] = info;
		info->id = id;
	}
	state_edicts = parse_config_dir(PROGRAM_PATH + "/common/state_edicts");
	imperial_reforms = parse_config_dir(PROGRAM_PATH + "/common/imperial_reforms");
	cb_types = parse_config_dir(PROGRAM_PATH + "/common/cb_types");
	wargoal_types = parse_config_dir(PROGRAM_PATH + "/common/wargoal_types");
	custom_country_colors = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/custom_country_colors/00_custom_country_colors.txt"));
	//estate_agendas = parse_config_dir(PROGRAM_PATH + "/common/estate_agendas"); //Not currently in use
	country_decisions = parse_config_dir(PROGRAM_PATH + "/decisions", "country_decisions");
	country_missions = parse_config_dir(PROGRAM_PATH + "/missions");

	//Parse out localised province names and map from province ID to all its different names
	province_localised_names = ([]);
	foreach (sort(get_dir(PROGRAM_PATH + "/common/province_names")), string fn) {
		mapping names = low_parse_savefile(Stdio.read_file(PROGRAM_PATH + "/common/province_names/" + fn) + "\n");
		string lang = L10n[fn - ".txt"] || fn; //Assuming that "castilian.txt" is the culture Castilian, and "TUR.txt" is the nation Ottomans
		foreach (names; string prov; array|string name) {
			if (arrayp(name)) name = name[0]; //The name can be [name, capitalname] but we don't care about the capital name
			province_localised_names[(string)prov] += ({({name, lang})});
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
		limit = {
			OR = {
				trade_goods = coal
				has_latent_trade_goods = coal
			}
		}
		log = \"PROV-TERRAIN: %<s has_coal=1\"
	}
	if = {
		limit = { has_port = yes is_wasteland = no }
		log = \"PROV-TERRAIN: %<s has_port=1\"
	}
", provid);
			foreach (terrain_definitions->categories; string type; mapping info) {
				script->write(
#"	if = {
		limit = { has_terrain = %s is_wasteland = no }
		log = \"PROV-TERRAIN: %s terrain=%[0]s\"
	}
", type, provid);
			}
			foreach (climates; string type; mixed info) if (arrayp(info)) {
				script->write(
#"	if = {
		limit = { has_climate = %s is_wasteland = no }
		log = \"PROV-TERRAIN: %s climate=%[0]s\"
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
		mapping terraininfo = terrain_definitions->categories[provinfo->terrain];
		if (int slots = (int)terraininfo->?allowed_num_of_buildings) building_slots[id] += slots;
		mapping climateinfo = static_modifiers[provinfo->climate];
		if (int slots = (int)climateinfo->?allowed_num_of_buildings) building_slots[id] += slots;
	}

	mapping cfg = ([]);
	catch {cfg = Standards.JSON.decode(Stdio.read_file(".eu4_preferences.json"));};
	if (mappingp(cfg) && cfg->tag_preferences) tag_preferences = cfg->tag_preferences;

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
	watch_game_log(inot);
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
# If --reconnect, will auto-retry until connection succeeds, ten-second
# retry delay. Will also reconnect after disconnection.
if len(sys.argv) < 3:
	print("USAGE: python3 %s ipaddress command")
	print("Useful commands include 'notify Name' and 'notify province Name'")
	sys.exit(0)

def goto(provid):
	# NOTE: This is currently synchronous, unlike the Pike version, which is
	# fully asynchronous. So if you queue multiple and then switch focus to
	# EU4, it will go through all of them. Also, retries for 30 seconds max.
	for retry in range(60):
		proc = subprocess.run(["xdotool", "getactivewindow", "getwindowname"], encoding="UTF-8", capture_output=True, check=True)
		if "Europa Universalis IV" in proc.stdout:
			subprocess.run(["xdotool", "key", "--delay", "125", "f", *list(str(provid)), "Return"], check=True)
			return
		time.sleep(0.5)
	print("Unable to find game window, not jumping to province")

reconnect = "--reconnect" in sys.argv
if reconnect: sys.argv.remove("--reconnect")
def client_connection():
	while "get connection":
		try: sock = socket.create_connection((sys.argv[1], 1444))
		except ConnectionRefusedError if reconnect else (): pass
		else: break
		time.sleep(10)
	print("Connected, listening for province focus messages")
	sock.send(" ".join(sys.argv[2:]).encode("UTF-8") + b"\n")
	partial = b""
	while "moar data":
		data = sock.recv(1024)
		if not data: break
		[*lines, data] = (partial + data).split(b"\n")
		for line in lines:
			line = line.decode("UTF-8")
			print(line)
			if line.startswith("provfocus "): goto(int(line.split(" ")[1]))
			if line.strip() == "exit": sys.exit(0)

while "reconnect":
	client_connection()
	if not reconnect: break
	time.sleep(10)

#endif
