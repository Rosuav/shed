//List files in a zip archive, with their MD5 sums
//Useful for checking against loose files, without fully extracting.
function unzip = ((object)"unzip.pike")->unzip;

int main(int argc, array(string) argv) {
	foreach (argv[1..], string arg) {
		string raw = Stdio.read_file(arg);
		werror(arg + "...\n");
		unzip(Stdio.Buffer(raw)) {
			write("%s  %s\n", String.string2hex(Crypto.MD5.hash(__ARGS__[1])), __ARGS__[0]);
		};
	}
}
