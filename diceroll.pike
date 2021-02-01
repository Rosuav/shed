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
#roll init
#roll weapon_dcs + 1 Excellent + 7d Excellency +1 Willpower
#roll table medium magic
#roll quiet 2d6 + 4
#roll shield d20 - 3
#roll note
#roll note 3
#roll note wondrousitem
#roll as rosuav spot + 4
# Below are not working or attempted yet
#roll 8d7/10 + 5d7/10/10
#roll stats
#roll stats 6/7 3/4d6
#roll alias greatsword 2d6 +1 ench +3 STR +1d6 Flame
roll test
roll test 20
roll test 20 10000
roll cheat d20 + 3
roll cheat
roll eyes
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
mapping NdM(string n, string _, string|void m) {return (["dice": (int)n, "sides": (int)m]);} //in the case of "10d", sides == 0
mapping dM(string _, string m) {return NdM("1", _, m);}
mapping N(string n) {return NdM(n, "d", "1");} //Note that "10d" renders as "10d0" but "10" renders as "10d1".
mapping pluscharsheet(mapping dice, string sign, string ... tag) {return plusroll(dice, sign, (["fmt": "charsheet"]), " ", tag[-1]);}
mapping rollmode(string mode, string|void _, string|void arg) {return (["tag": arg || "", "fmt": mode]);}
mapping addflag(string flag, string _, mapping dice) {return dice | ([flag: 1]);}
mapping addflagval(string flag, string _1, string val, string _2, mapping dice) {return dice | ([flag: val]);}
mapping testroll(string mode, string _1, string max, string _2, string avg) {return (["fmt": mode, "max": (int)(max || 20), "avg": (int)(avg || 10000)]);}
//These words, if at the start of a dice roll, will be treated as keywords. Anywhere
//else, they're just words. It means that "roll quiet d20" is easier to distinguish
//from "roll floof + 20", although technically there's no situation in which it would
//actually be ambiguous.
multiset(string) leadwords = (multiset)("quiet shield table note as cheat uncheat test eyes" / " ");

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
				return ({"word", word});
			}
			at_start = 0; //Anything other than a word or whitespace means we're not at the start.
			sscanf(diceroll, "%1s%s", string char, diceroll); return char;
		}
		string|array shownext() {string lead = diceroll[..8]; mixed ret = next(); write("%O ==>%{ %O%}\n", lead, Array.arrayify(ret)); return ret;}
		write("************\n%s\n", diceroll);
		sscanf(diceroll, "roll %s", diceroll);
		mapping|string result = parser->parse(has_value(argv, "-v") ? shownext : next, this);
		write("%O\n", result);
		/*
		Certain special forms are not handled by this grammar:
		- roll eyes
		- roll cheat (without other arguments)
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
		*/
	}
}
