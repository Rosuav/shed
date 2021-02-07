//Testbed for a new diceroller for Minstrel Hall
constant tests = #"
#roll (damage) 2d6 + d6 Backstab + d10 Fire
#roll d20 + 2 STR + 3 BAB - 2 PA
#roll WIT + 5d Awareness
#roll 2d
#roll PER + Survival
#roll 6d -1d Soak +6d Threshold
#roll (withering talons) 9d
#roll weapon_dmg - 1d soak + 6d threshold
#roll d20 - d6 - 2d8
#roll init
#roll weapon_dcs + 1 Excellent + 7d Excellency +1 Willpower
#roll table
#roll table medium magic
#roll quiet 2d6 + 4
#roll shield d20 - 3
#roll note
#roll note 3
#roll note wondrousitem
#roll as rosuav spot + 4
#roll init
#roll search + 2
#roll (search) + 2
#roll (search) d20 + 2
#roll test
#roll test 20
#roll test 20 10000
#roll cheat d20 + 3
#roll uncheat d20 + 3
#roll cheat
#roll eyes
#roll (search) take10 + 5
#roll d20 + 2 (STR) + 3 (BAB) - 2 (PA)
#roll 8d7/10 + 5d7/10
#roll b10 8d7/10 + 5d7/10
#roll stats
#roll stats 6 3d6
#roll stats 6 3/4d6
#roll stats 6/7 3/4d6
#roll alias
#roll alias greatsword 2d6 +1 ench +3 STR +1d6 Flame
#roll alias \"greatsword\"
#roll unalias greatsword
#roll unalias \"greatsword\"
#roll greatsword
#roll alias \"foo bar fum\" d20 + 3 Foo + 2 Bar + 5 Fum
#roll foo bar fum
#roll \"foo bar fum\"
#roll (foo bar fum)
#roll attack_1_crit
#roll spot
#roll (spot)
#roll (spot) d20 + spot
#roll weapon_wth
#roll (weapon_wth)
#roll (weapon_wth) 0 + weapon_wth
#roll 5d DEX + 3d Stealth
roll (Case Scene) PER + Investigation
";

mapping tagonly(string tag) {return (["tag": tag, "roll": ({(["fmt": "charsheet", "tag": tag])})]);} //Magically get it from the charsheet eg "roll init"
mapping no_tag(mapping firstroll) {return (["roll": ({firstroll})]);}
mapping taggeddice(string tag, mapping firstroll) {return tagonly(tag) | no_tag(firstroll);}
mapping plusroll(mapping dice, string sign, mapping roll, string|void _, string|void tag) {
	dice->roll += ({roll | (["sign": sign, "tag": tag])});
	return dice;
}
string joinwords(string ... words) {return words * "";}
mixed take2(mixed _, mixed ret) {return ret;}
array firstlast(mixed ... ret) {return ({ret[0], ret[-1]});}
mapping NdM(string n, string _, string|void m) {return (["dice": (int)n, "sides": (int)m]);} //in the case of "10d", sides == 0
mapping NdTM(string n, string _1, string t, string _2, string m) {return NdM(n, _1, m) | (["threshold": (int)t]);} //Exalted-style "d10, goal is 7"
mapping dM(string _, string m) {return NdM("1", _, m);}
mapping N(string n) {return NdM(n, "d", "1");} //Note that "10d" renders as "10d0" but "10" renders as "10d1".
mapping takeN(string _, string n) {return NdM("1", "d", "20") | (["fmt": "take", "result": (int)n]);}
mapping pluscharsheet(mapping dice, string sign, string ... tag) {return plusroll(dice, sign, (["fmt": "charsheet"]), " ", tag[-1]);}
mapping rollmode(string mode, string|void _, string|void arg) {return (["tag": arg || "", "fmt": mode]);}
mapping addflag(string flag, string _, mapping dice) {return dice | ([flag: 1]);}
mapping addflagval(string flag, string _1, string val, string _2, mapping dice) {return dice | ([flag: val]);}
mapping addflagval_compact(string flag, string val, string _2, mapping dice) {return dice | ([flag: val]);}
mapping testroll(string mode, string _1, string max, string _2, string avg) {return (["fmt": mode, "max": (int)(max || 20), "avg": (int)(avg || 10000)]);}
mapping stats(string _1, string _2, array statcount, string _3, array dicecount, string _, string sides) {return (["fmt": "stats", "statcount": (array(int))statcount, "dicecount": (array(int))dicecount, "sides": (int)sides]);}
mapping defaultstats(string _1) {return stats(_1, " ", ({6, 7}), " ", ({3, 4}), "d", "6");}
mapping rollalias(string cmd, string _1, string alias, string _2, string expansion) {return (["fmt": cmd, "alias": alias, "expansion": expansion]);}
//These words, if at the start of a dice roll, will be treated as keywords. Anywhere
//else, they're just words. It means that "roll quiet d20" is easier to distinguish
//from "roll floof + 20", although technically there's no situation in which it would
//actually be ambiguous. Note that "roll as foo cheat" doesn't work, but "roll cheat as foo"
//does; but due to this disambiguation, "roll as cheat" will always fail.
multiset(string) leadwords = (multiset)("quiet shield table note as cheat uncheat test eyes eval b stats alias unalias" / " ");

string word(string w) {if (!has_value(w, ' ')) return w; return sprintf("\"%s\"", w);}
//Reconstitute a roll command from the AST. This will always produce
//a string which, if parsed, will yield the same AST; to the greatest
//extent possible, it should return something elegant and clean. In
//the face of multiple options, usually choose the one a human would
//most prefer to type; it's acceptable to explicitly state some
//defaults, but don't overdo it.
string reconstitute(mapping info) {
	string ret = "";
	switch (info->fmt) {
		case "cheat": case "eyes": case "eval": case "table": case "note":
			if (info->tag != "") return info->fmt + " " + info->tag;
			return info->fmt;
		case "test": return sprintf("test %d %d", info->max, info->avg);
		case "alias": case "unalias":
			ret = info->fmt;
			if (info->alias) ret += " " + word(info->alias);
			if (info->expansion) ret += " " + reconstitute(info->expansion);
			return ret;
		case "stats": return sprintf("stats %d/%d %d/%dd%d", @info->statcount, @info->dicecount, info->sides);
	}
	foreach ("quiet shield cheat uncheat" / " ", string flag)
		if (info[flag]) ret += flag + " ";
	if (info->as) ret += "as " + word(info->as) + " ";
	if (info->b) ret += "b" + info->b + " ";
	int skipfirst = 0;
	if (info->tag) {
		skipfirst = info->roll[0]->fmt == "charsheet" && info->roll[0]->tag == info->tag; //Implicit charsheet roll
		if (skipfirst && !has_value(info->tag, ' ')) ret += word(info->tag) + " "; //Omit the parens for this format. Not strictly necessary but looks better.
		else ret += sprintf("(%s) ", info->tag);
	}
	foreach (info->roll; int i; mapping r) {
		if (!i && skipfirst) continue; //Implicit charsheet roll
		if (i) ret += r->sign == "-" ? "- " : "+ "; //Don't rely on r->sign being "+", it won't always be set
		if (r->fmt == "charsheet") {ret += word(r->tag) + " "; continue;}
		if (r->fmt == "take") ret += "take" + r->result + " ";
		else if (r->threshold) ret += sprintf("%dd%d/%d ", r->dice, r->threshold, r->sides);
		else if (!r->sides) ret += sprintf("%dd ", r->dice);
		else if (r->sides == 1) ret += sprintf("%d ", r->dice);
		else if (r->dice == 1) ret += sprintf("d%d ", r->sides);
		else ret += sprintf("%dd%d ", r->dice, r->sides);
		if (r->tag) ret += sprintf("(%s) ", r->tag);
	}
	return ret[..<1]; //It'll have a space at the end.
}

int main(int argc, array(string) argv) {
	Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("diceroll.grammar");
	write("Grammar parsed successfully.\n");
	//TODO: Walk the grammar and find all leading keywords rather than hard coding them
	foreach (tests / "\n", string diceroll) if (diceroll != "" && diceroll[0] != '#') {
		int at_start = 1;
		string|array next() {
			if (diceroll == "") return "";
			if (sscanf(diceroll, "%[ \t]%s", string ws, diceroll) && ws != "") {
				if (diceroll == "") return ""; //Trailing whitespace is ignored.
				//Since we're using a fairly naive LR parser, the ambiguity of " " "+" against " " "blah"
				//can't easily be resolved. So the simplest fix is here in the tokenizer: any sequence of
				//spaces followed by a "+" or a "-" will be collapsed to just the sign itself.
				if (sscanf(diceroll, "%1[-+]%s", string sign, diceroll)) return sign;
				return " "; //Otherwise, treat all non-EOL whitespace as a single space
			}
			if (sscanf(diceroll, "%[0-9]%s", string digits, diceroll) && digits != "") return ({"digits", digits});
			if (sscanf(diceroll, "%[A-Z_a-z]%s", string word, diceroll) && word != "") {
				if (at_start && leadwords[word]) return word;
				else at_start = 0; //Once we've had any non-lead word, we're not at the start any more.
				if (word == "d") return "d"; //The letter "d" on its own isn't a word, it's probably a dice-roll marker
				if (word == "take" && diceroll != "" && has_value("0123456789", diceroll[0])) return "take"; //eg "take20"
				//Digits are allowed inside a word, if and only if it's not "dN" or "takeN"
				sscanf(diceroll, "%[A-Z_a-z0-9]%s", string moreword, diceroll);
				return ({"word", word + moreword});
			}
			at_start = 0; //Anything other than a lead word, digits, or whitespace means we're not at the start.
			if (sscanf(diceroll, "\"%[^\"]\"%s", string str, diceroll)) {
				//TODO: Allow backslashes inside quoted strings?
				//Current definition is simple: a quoted string acts like a single word.
				//This allows quoted strings to appear in a variety of contexts where
				//multi-word tokens wouldn't work; it also allows them to disambiguate
				//when a bare word would be taken as a keyword. It does, however, create
				//odd situations, eg <roll "foo"bar> which is tokenized as two abutted
				//words - an otherwise-impossible sequence of tokens. That's up to the
				//user, I think.
				return ({"word", str});
			}
			sscanf(diceroll, "%1s%s", string char, diceroll); return char;
		}
		string|array shownext() {string lead = diceroll[..8]; mixed ret = next(); write("%O ==>%{ %O%}\n", lead, Array.arrayify(ret)); return ret;}
		write("************\n%s\n", diceroll);
		sscanf(diceroll, "roll %s", diceroll);
		mapping|string result = parser->parse(has_value(argv, "-v") ? shownext : next, this);
		//write("%O\n", result);
		write("roll %s\n", reconstitute(result));
		//Verify the reconstitution by reparsing it
		string parse1 = Standards.JSON.encode(result);
		at_start = 1; diceroll = reconstitute(result);
		string parse2 = Standards.JSON.encode(parser->parse(next, this));
		if (parse1 != parse2) write("%s\n%s\n", parse1, parse2);
		/*
		The resulting mapping has the following optional attributes:
		- tag => A display tag (no effect on the outcome of the roll)
		- quiet => 1 if the roll should be made quietly
		- shield => 1 if the roll should be "behind the shield"
		- fmt => special roll format with custom code. Only specific keywords possible.
		- as => alternate charsheet to roll from (instead of the caller's)
		It also has an array, result->roll, which has a sequence of roll parts.
		Each roll part is a mapping. If part->fmt == "charsheet", it will have
		part->tag which, combined with the charsheet, defines the dice to be
		rolled; otherwise, it has part->dice and part->sides. When sides is 0,
		the actual roll pattern comes from the charsheet; when it is 1, it's a
		constant (4d1 will always have a value of exactly 4). The part may have
		a tag for display purposes (same one used for fmt charsheet).

		** CHANGES FROM CURRENT **
		You can no longer "roll major magic". Instead: "roll table major magic".
		Similarly, "roll kwd" (which gave the list of those) is now "roll table".
		"roll glitch" was a redirect advising the use of threshold mode.
		Threshold rolls (5d7/10) no longer have a "bonus" mode that lists extra
		bonus successes (5d7/10/10). Instead, the roll itself should say whether
		you get double 10s or double 9s or whatever: "roll b10 5d7/10". More
		likely, though, people will just ignore this and manually count extras.
		*/
	}
}
