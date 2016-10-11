/* Trim a set of files to remove their dialogue.

A lot of CDs consist of a series of tracks that start with music, but then have
dialogue tacked on. It's not easy to make a "music only" playlist. Hence, this.

Create a file with a list of tracks and their trim positions:
PREFIX [hh:]mm:ss

If no file is found matching PREFIX*, the line is ignored. If more than one is,
error. Otherwise, the file is trimmed (using ffmpeg).

Lines with a prefix and no timestamp represent tracks with no dialogue and thus
no trim point. They will be copied unchanged, subject to file extension checks.

At no time are the original files changed. A new directory is created.
*/
string preferred_ext = "ogg";
//multiset(string) permitted_exts = (<"wav", "mp3">); //Additional extensions accepted in copy mode
string target = "MusicOnly";

int main(int argc, array(string) argv)
{
	if (argc < 2) exit(1, "USAGE: pike %s templatefile\nSee source comments for details.\n", argv[0]);
	object stat = file_stat(target);
	if (!stat) mkdir(target);
	else if (!stat->isdir) exit(1, "ERROR: Target %O exists and is not a directory.\n", target);
	rm(((target + "/") + get_dir(target)[*])[*]);
	array(string) dir = get_dir();
	string converter;
	foreach (({"ffmpeg", "avconv"}), string cmd)
		if (!Process.run(({"which", cmd}))->exitcode) {converter = cmd; break;}
	if (!converter) exit(1, "Requires ffmpeg (can fall back on avconv)\n");
	foreach (Stdio.read_file(argv[1]) / "\n", string line)
	{
		if (line == "") continue;
		sscanf(line, "%s %s", line, string trim);
		array matches = filter(dir, has_prefix, line);
		if (!sizeof(matches)) continue; //Ignore any that aren't found
		if (sizeof(matches) > 1) exit(1, "ERROR: Prefix %O matches multiple files\n", line);
		if (!trim && trim != "" && has_suffix(matches[0], "." + preferred_ext))
		{
			//Easy: just copy the file in as-is.
			//TODO: Hardlink or symlink if that's an option
			Stdio.cp(matches[0], target + "/" + matches[0]);
			continue;
		}
		string dest = target + "/" + (matches[0] / ".")[..<1] * "." + "." + preferred_ext;
		//Okay, let's do some conversions.
		array(string) cmd = ({converter, "-i", matches[0]});
		if (trim) cmd += ({"-t", trim});
		//cmd += ({"-c", "copy"});
		cmd += ({dest});
		Process.create_process(cmd)->wait();
	}
}
