int main(int argc, array(string) argv)
{
	array(string) words = Stdio.read_file("/usr/share/dict/words") / "\n" - ({""});
	mapping(string:array(string)) matches = ([]);
	foreach (words, string word)
	{
		foreach (argv[1..], string pat)
		{
			array cur = array_sscanf("^" + word + "$", "^" + pat + "$");
			if (sizeof(cur)) matches[cur[0]] += ({word});
		}
	}
	foreach (matches; string token; array words) if (sizeof(words) > 1)
	{
		write("%s\n", words * " ");
	}
}
