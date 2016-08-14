int main(int argc, array(string) argv)
{
	mapping args = Arg.parse(argv);
	int dryrun = !args->rename; //Dry run is the default.
	array(string) newnames = Stdio.read_file(args[Arg.REST][0])/"\n" - ({""});
	foreach (args[Arg.REST][1..], string fn)
	{
		sort(String.fuzzymatch(newnames[*], fn), newnames);
		if (dryrun) write("mv %O %O\n", fn, newnames[-1]);
		else mv(fn, newnames[-1]);
		newnames = newnames[..<1];
	}
}
