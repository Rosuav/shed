/* Probe an oddity in Crypto.Random

If Pike is installed normally, this error comes up:
$ pike -e Crypto.Random
/usr/local/pike/8.1.6/lib/modules/Crypto.pmod/Random.pmod.o:-: Warning: Decode failed: Error while decoding program(/usr/local/pike/8.1.6/lib/modules/Crypto.pmod/Random.pmod:23):
Bad function identifier offset for random_string:function(int(0..2147483647) : string(8bit)): 3 != 0

It appears to be to do with the way dumping works. There's some odd difference
between using the installed pike and the one from the build dir.
*/

int main(int argc, array(string) argv)
{
	if (argc == 1) argv += ({Program.defined(object_program(Crypto.Random))});
	program p = compile_file(argv[-1]);
	string s = encode_value(p, master()->Encoder(p));
	if (argv[1] == "-x")
	{
		//This is the subprocess, using a different Pike interpreter.
		write(s);
		return 0;
	}
	string installed = s;
	string build = Process.run(({"pike/bin/pike", argv[0], "-x", argv[1]}))->stdout;
	if (installed == build) {write("Identical.\n"); return 0;}
	//Hex-dump both files for readability and diff them.
	installed = Process.run(({"hd"}), (["stdin": installed]))->stdout;
	build = Process.run(({"hd"}), (["stdin": build]))->stdout;
	foreach (Array.transpose(Array.diff(installed/"\n", build/"\n")),
		[array(string) inst, array(string) buil])
	{
		string same = " " + inst * "\n " + "\n";
		if (same == " " + buil * "\n " + "\n") write(same);
		else write("\x1b[31m%{-%s\n%}\x1b[32m%{+%s\n%}\x1b[0m", inst, buil);
	}
	write("%d %d\n", sizeof(installed), sizeof(build));
}
