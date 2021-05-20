int main(int argc, array(string) argv) {
	array files = ({ });
	int shuffle = 0;
	foreach (argv[1..], string dir) {
		if (dir == "--shuffle") {shuffle = 1; continue;}
		array cur = glob("*.wav", get_dir(dir)); //Note that this will skip precisely TWO files that exist in MP3 instead of WAV
		cur -= glob("*(seamless)*", cur); //Exclude files designed to be looped (they're duplicates of others)
		sort((array(int))cur, cur); //Sort by the track numbers, which vary in length
		files += (dir + "/") + cur[*];
	}
	if (shuffle) Array.shuffle(files);
	Process.exec("vlc", @files);
}
