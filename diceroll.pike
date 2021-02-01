//Testbed for a new diceroller for Minstrel Hall
constant tests = #"
#roll (damage) 2d6 + d6 Backstab + d10 Fire
roll d20 + 2 STR + 3 BAB - 2 PA
roll WIT + 5d Awareness
roll 2d
roll PER + Survival
roll 6d -1d Soak +6d Threshold
roll (withering talons) 9d
roll weapon_dmg - 1d soak + 6d threshold
roll init
roll weapon_dcs + 1 Excellent + 7d Excellency +1 Willpower
";

mapping tagonly(string tag) {return (["tag": tag, "roll": ({(["fmt": "charsheet"])})]);} //Magically get it from the charsheet eg "roll init"
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

int main() {
	Parser.LR.Parser parser = Parser.LR.GrammarParser.make_parser_from_file("diceroll.grammar");
	write("Grammar parsed successfully.\n");
	foreach (tests / "\n", string diceroll) if (diceroll != "" && diceroll[0] != '#') {
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
			if (sscanf(diceroll, "%[A-Za-z]%s", string word, diceroll) && word != "") {
				if (word == "d") return "d"; //The letter "d" on its own isn't a word, it's probably a dice-roll marker
				return ({"word", word});
			}
			sscanf(diceroll, "%1s%s", string char, diceroll); return char;
		}
		string|array shownext() {mixed ret = next(); write("==>%{ %O%}\n", Array.arrayify(ret)); return ret;}
		write("************\n%s\n************\n", diceroll);
		sscanf(diceroll, "roll %s", diceroll);
		mixed result = parser->parse(shownext, this);
		write("************\n%O\n************\n", result);
		break;
	}
}
