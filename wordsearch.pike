mapping counter(string ltrs)
{
	mapping ret = ([]);
	foreach (ltrs/"", string l) ret[l]++;
	return ret;
}

int main(int argc, array(string) argv)
{
	string ltrs = argv[1..] * "";
	if (ltrs == "") exit(1, "Need some letters.\n");
	array(string) words = Stdio.read_file("/usr/share/dict/words") / "\n";
	mapping ltrcount = counter(ltrs);
	int best = 0;
	nextword: foreach (words, string w)
	{
		foreach (counter(w); string l; int n) if (n > ltrcount[l]) continue nextword;
		if (sizeof(w) <= best) continue;
		write(w + "\n");
		best = sizeof(w);
	}
}
