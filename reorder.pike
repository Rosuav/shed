/* Reorder the files listed in the arguments by renaming them
to include a sequential number. Respects a common prefix. */
int main(int argc,array(string) argv)
{
	string pfx = String.common_prefix(argv[1..]);
	foreach (argv[1..]; int idx; string from)
		mv(from, sprintf("%s%d %s", pfx, idx+1, from-pfx));
}
