Regexp.SimpleRegexp nonword = Regexp.SimpleRegexp("[^A-Z ]");
string make_cryptogram(string plain) {
	string stripped = nonword->replace(upper_case(plain), "");
	array letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" / 1;
	mapping cipher = mkmapping(letters, Array.shuffle(letters + ({ })));
	return replace(stripped, cipher);
}

int main(int argc, array(string) argv) {
	foreach (argv[1..], string arg) {
		arg = Stdio.read_file(arg) || arg;
		foreach (arg / "\n", string line)
			write("%s\n%s\n", line, make_cryptogram(line));
	}
}
