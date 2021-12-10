object parsevdf = (object)"parsevdf.pike";

mapping items_game;
int verbose = 0;

void display_quest(int q, int indent, int|void showstars) {
	mapping quest = items_game->quest_definitions[(string)q];
	if (!stringp(quest->expression)) return;
	string expr = quest->expression;
	string pfx = " " * indent;
	if (showstars) pfx += quest->operational_points + " stars -- ";
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
			write("%sEither:\n", pfx);
			display_quest(subquests[0], indent + 4);
			write("%*sOr:\n", indent, " ");
			display_quest(subquests[1], indent + 4);
			return;
		}
		//Type 2: Scavenger hunt
		string desc = tot == sizeof(subquests) ? "Complete in any order" : sprintf("Complete at least %d of", tot);
		write("%s%s:\n", pfx, desc);
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
		write("%s%s:\n", pfx, desc);
		foreach (subquests, int q) display_quest(q, indent + 4);
		return;
	}
	//4) Defined-Elsewhere quests: quest->expression is "%act_win_match%"
	//   Used for Guardian missions, possibly Co-Op Strike too
	if (expr == "%act_win_match%") {
		string weap = quest->string_tokens->?weapon || "";
		if (weap != "") weap = " (" + weap + ")";
		write("%sWin %s %s%s\n", pfx, quest->gamemode, quest->map, weap);
		return;
	}
	//5) Everything else. The quest->expression is worth displaying, as are some string_tokens
	string action = expr;
	if (!verbose) {
		//Abbreviate the display unless verbosity is requested
		if ((int)quest->points > 1 && quest->string_tokens->?actions) action = quest->points + " " + quest->string_tokens->actions;
		if ((int)quest->points == 1 && quest->string_tokens->?action) action = quest->string_tokens->action;
	}
	write("%sOn %s %s, %s\n", pfx, quest->gamemode, quest->map || quest->mapgroup, action);
	//write("%s%*O\n", pfx, (["indent": indent]), quest);
}

mapping vdf_cache = ([]);
mapping parse_vdf_cached(string fn, string|void encoding) {
	string raw = Stdio.read_file(fn);
	sscanf(Crypto.SHA256.hash(raw), "%32c", int hashnum);
	string hash = sprintf("%x\n", hashnum);
	if (vdf_cache[fn]->?hash == hash) return vdf_cache[fn]->data;
	//Cache miss. Do the full parse.
	string txt = encoding ? Charset.decoder(encoding)->feed(raw)->drain() : raw;
	mapping ret = parsevdf->parse_vdf(txt);
	vdf_cache->dirty = 1;
	vdf_cache[fn] = (["hash": hash, "data": ret]);
	return ret;
}

int main(int argc, array(string) argv) {
	catch {vdf_cache = Standards.JSON.decode(Stdio.read_file(".cs_missions.json"));};
	string path = getenv("HOME") + "/tf2server/steamcmd_linux/csgo/csgo";
	mapping l10n = parse_vdf_cached(path + "/resource/csgo_english.txt", "utf16");
	items_game = parse_vdf_cached(path + "/scripts/items/items_game.txt");
	if (m_delete(vdf_cache, "dirty")) Stdio.write_file(".cs_missions.json", Standards.JSON.encode(vdf_cache, 1));
	mapping op;
	if (has_value(argv, "-v")) verbose = 1;
	foreach (argv[1..], string opid) if (op = items_game->seasonaloperations[opid]) break;
	//If none specified, go with the latest (but the keys are strings, so pick max by int)
	if (!op) op = items_game->seasonaloperations[(string)max(@(array(int))indices(items_game->seasonaloperations))];
	foreach (op->quest_mission_card->quests; int wk; string quests) {
		write("\nWeek %d (%s stars max):\n", wk + 1, op->quest_mission_card->operational_points[wk]);
		if (quests == "locked") {write("\t(Locked)\n"); continue;}
		foreach (quests / ",", string qq) {
			sscanf(qq, "%d-%d", int start, int end);
			if (!end) start = end = (int)qq;
			for (int q = start; q <= end; ++q)
				display_quest(q, 8, 1);
		}
	}
}
