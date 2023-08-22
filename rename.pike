//Rename files according to an sscanf pattern
int main(int argc, array(string) argv)
{
	mapping args = Arg.parse(argv);
	if (args->help || args->h || sizeof(args[Arg.REST]) != 2)
		exit(0, "USAGE: pike %s [-n] source_pattern dest_pattern\n");
	array(string) files = sort(get_dir());
	[string from, string to] = args[Arg.REST];
	int dryrun = args->n;
	int maxlen = max(@sizeof(files[*]));
	foreach (files, string fn) {
		array match = array_sscanf(fn, from);
		if (!match) {
			if (args->n) write("%-*s | <not matched>\n", maxlen, fn);
			continue;
		}
		string newname;
		if (mixed ex = catch {newname = sprintf(to, @match);}) {
			write("%-*s | <%s>\n", maxlen, fn, (describe_error(ex) / "\n")[0]);
			continue;
		}
		if (args->n) write("%-*s | %s\n", maxlen, fn, newname);
		else mv(fn, newname);
	}
}
