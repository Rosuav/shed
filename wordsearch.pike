constant score = "02210313074020029000033739";
mapping ltrscore = mkmapping(enumerate('z' - 'a' + 1, 1, 'a'), (array(int))(score / 1));

mapping counter(string ltrs)
{
	mapping ret = ([]);
	foreach (ltrs/"", string l) ret[l]++;
	return ret;
}

array(string) listwords(array(string) words, string ltrs, int minlength) {
	mapping ltrcount = counter(ltrs);
	array matches = ({ });
	nextword: foreach (words, string w)
	{
		foreach (counter(w); string l; int n) if (n > ltrcount[l]) continue nextword;
		if (sizeof(w) < minlength && sizeof(w) < sizeof(ltrs)) continue;
		matches += ({w});
	}
	sort(sizeof(matches[*]), matches);
	return matches;
}

int main(int argc, array(string) argv)
{
	string ltrs = argv[1..] * "";
	if (ltrs == "") exit(1, "Need some letters.\n");
	int hidden = sscanf(ltrs, "%s?", ltrs);
	sscanf(ltrs, "%s%d", ltrs, int minlength); if (!minlength) minlength = 4;
	string fn = "/usr/share/dict/words";
	if (has_value(ltrs, "+")) {fn = "/usr/share/dict/american-english-insane"; ltrs = replace(ltrs, "+", "");}
	array(string) words = Stdio.read_file(fn) / "\n";
	array(string) matches = listwords(words, ltrs, minlength);
	foreach (matches, string w)
		write("%2d %s\n", sizeof(w) + `+(@ltrscore[((array)w)[*]]), w);
	if (!sizeof(words) || !hidden) return 0;
	int best = sizeof(matches[-1]) + 1;
	for (int ltr = 'a'; ltr <= 'z'; ++ltr) {
		write("%c\r", ltr);
		string word = listwords(words, sprintf("%s%c", ltrs, ltr), minlength)[-1];
		if (sizeof(word) >= best) {best = sizeof(word); write("Suggest: %s%c --> %s\n", ltrs, ltr, word);}
	}
}
