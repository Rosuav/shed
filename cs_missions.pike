object parsevdf = (object)"parsevdf.pike";

mapping items_game;
mapping l10n_tokens;
int verbose = 0;
constant htmltags = "<i> </i> <b> </b>" / " ";
mapping striptags = mkmapping(htmltags, ({""}) * sizeof(htmltags));

string l10n(string msg, mapping|void variables) {
	if (has_prefix(msg, "#")) msg = l10n_tokens[msg[1..]] || msg;
	msg = replace(msg, striptags); //Strip out HTML tags used by Panorama
	if (!variables) return msg;
	string ret = "";
	while (sscanf(msg, "%s{%s:%s}%s", string txt, string fmt, string var, msg) == 4) {
		ret += txt + (variables[var] || "{" + var + "}");
	}
	return ret + msg;
}

void display_quest(int q, int indent, int|void showstars) {
	mapping quest = items_game->quest_definitions[(string)q];
	if (!stringp(quest->expression)) return;
	//TODO: Add quest->location b/c the placeholders try to use it
	string expr = quest->expression;
	string pfx = " " * indent;
	void say(strict_sprintf_format fmt, sprintf_args ... args) {
		if (showstars) {
			fmt = quest->operational_points + " stars -- " + fmt;
			if (verbose >= 2) fmt = "[" + q + "] " + fmt;
			showstars = 0;
			fmt = pfx + fmt + "\n";
			pfx += "  ";
		}
		else fmt = pfx + fmt + "\n";
		write(fmt, @args);
	}
	if (quest->loc_name) say("%s", l10n(quest->loc_name, quest));
	if (quest->loc_description) say("%s", l10n(quest->loc_description, quest));
	//There are several broad types of quest available.
	//1) Either-Or quests: quest->expression is "QQ:|%d|%d", quest->points is "1".
	//   Used for linked pairs eg "Win 21 rounds, or win 1 match"
	//2) Scavenger Hunt quests: quest->expression is "QQ:%{|%d%}", quest->points might be "%d" or "%d,%d,%d" but the largest number is sizeof(expressions)
	//   Used for "Complete mission objectives in any order"
	if (sscanf(expr, "QQ:%{|%d%}", array subquests) && sizeof(subquests)) {
		subquests *= ({ }); //Flatten array of single-item arrays into a straight array
		array(int) points = (array(int))(quest->points / ",");
		int tot = max(@points);
		//Type 1: Either-Or
		if (tot == 1 && sizeof(subquests) == 2) {
			say("Either:");
			display_quest(subquests[0], indent + 4);
			say("Or:");
			display_quest(subquests[1], indent + 4);
			return;
		}
		//Type 2: Scavenger hunt
		string desc = tot == sizeof(subquests) ? "Complete in any order" : sprintf("Complete at least %d of", tot);
		say("%s:", desc);
		foreach (subquests, int q) display_quest(q, indent + 4);
		return;
	}
	//3) Progessive quests: quest->expression is "QQ:%{>%d%}", quest->points is "%d" == sizeof expressions
	//   Used for things like "get a kill from each of these named locations"
	if (sscanf(expr, "QQ:%{>%d%}", array subquests) && sizeof(subquests)) {
		subquests *= ({ });
		array(int) points = (array(int))(quest->points / ",");
		int tot = max(@points);
		string desc = tot == sizeof(subquests) ? "Complete in sequence" : sprintf("Complete at least %d of", tot);
		say("%s:", desc);
		foreach (subquests, int q) display_quest(q, indent + 4);
		return;
	}
	if (verbose < 1) return; //Everything else should have a loc_description
	//4) Defined-Elsewhere quests: quest->expression is "%act_win_match%"
	//   Used for Guardian missions, possibly Co-Op Strike too
	string action = expr;
	if (expr == "%act_win_match%") {
		action = l10n(quest->string_tokens->?weapon || "");
	}
	//5) Everything else. The quest->expression is worth displaying, as are some string_tokens
	string challenge = l10n(quest->string_tokens->commandverb || "") + " ";
	if ((int)quest->points > 1 && quest->string_tokens->?actions)
		challenge += l10n(quest->points) + " " + l10n(quest->string_tokens->actions);
	if ((int)quest->points == 1 && quest->string_tokens->?action)
		challenge += l10n(quest->string_tokens->action);
	if (verbose >= 2 && action != "") challenge += " with " + action;
	say("On %s %s: %s", quest->gamemode, quest->map || quest->mapgroup, challenge);
	if (verbose >= 3) say("%*O", (["indent": indent]), quest);
}

mapping vdf_cache = ([]);
mapping parse_vdf_cached(string fn, string|void encoding) {
	string raw = Stdio.read_file(fn);
	sscanf(Crypto.SHA256.hash(raw), "%32c", int hashnum);
	string hash = sprintf("%x\n", hashnum);
	if (vdf_cache[fn]->?hash == hash) return vdf_cache[fn]->data;
	//Cache miss. Do the full parse.
	string txt = encoding ? Charset.decoder(encoding)->feed(raw)->drain() : raw;
	write("Parsing %s...\n", fn);
	mapping ret = parsevdf->parse_vdf(txt);
	vdf_cache->dirty = 1;
	vdf_cache[fn] = (["hash": hash, "data": ret]);
	return ret;
}

int main(int argc, array(string) argv) {
	catch {vdf_cache = Standards.JSON.decode(Stdio.read_file(".cs_missions.json"));};
	string path = getenv("HOME") + "/tf2server/steamcmd_linux/csgo/csgo";
	l10n_tokens = parse_vdf_cached(path + "/resource/csgo_english.txt", "utf16")->Tokens;
	items_game = parse_vdf_cached(path + "/scripts/items/items_game.txt");
	if (m_delete(vdf_cache, "dirty")) Stdio.write_file(".cs_missions.json", Standards.JSON.encode(vdf_cache, 1));
	mapping op;
	foreach (argv[1..], string opid) {
		if (opid == "-v") ++verbose;
		if (opid == "-vv") verbose += 2;
		if (opid == "-vvv") verbose += 3;
		if (op = items_game->seasonaloperations[opid]) break;
	}
	//If none specified, go with the latest (but the keys are strings, so pick max by int)
	if (!op) op = items_game->seasonaloperations[(string)max(@(array(int))indices(items_game->seasonaloperations))];
	foreach (op->quest_mission_card->quests; int wk; string quests) {
		write("\nWeek %d (%s stars max): %s\n", wk + 1,
			op->quest_mission_card->operational_points[wk],
			l10n(op->quest_mission_card->name[wk]),
		);
		if (quests == "locked") {write("\t(Locked)\n"); continue;}
		foreach (quests / ",", string qq) {
			sscanf(qq, "%d-%d", int start, int end);
			if (!end) start = end = (int)qq;
			for (int q = start; q <= end; ++q)
				display_quest(q, 8, 1);
		}
	}
}
