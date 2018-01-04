int main(int argc, array(string) argv)
{
	if (argc < 2) exit(1, "USAGE: pike %s program [arg [arg [arg...]]]\nRuns program with the given args, shuffled.\n");
	Process.exec(argv[1], @Array.shuffle(argv[2..]));
}
