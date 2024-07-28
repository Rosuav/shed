Regexp.SimpleRegexp nonword = Regexp.SimpleRegexp("[^A-Z ]");
string make_cryptogram(string plain) {
	sscanf(plain, "%[0-9. ]%s", string pfx, plain);
	string stripped = nonword->replace(upper_case(plain), "");
	stripped = upper_case(plain); //Easy mode: keep the punctuation.
	array letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" / 1;
	mapping cipher = mkmapping(letters, Array.shuffle(letters + ({ })));
	return pfx + replace(stripped, cipher);
}

int main(int argc, array(string) argv) {
	foreach (argv[1..], string arg) {
		arg = Stdio.read_file(arg) || arg;
		foreach (arg / "\n", string line)
			//write("%s\n%s\n", line, make_cryptogram(line)); //Compare?
			write("%s\n", make_cryptogram(line)); //Or just show the puzzles?
	}
}
