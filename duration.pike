//total duration of set of files
//parse ffmpeg output

int main(int argc, array(string) argv)
{
	int tot = 0;
	int failed = 0;
	foreach (argv[1..], string fn)
	{
		string info = Process.run(({"ffmpeg", "-i", fn}))->stderr;
		sscanf(info, "%*s\n  Duration: %s,", string duration);
		if (!duration) {write("%s: <unknown>\n", fn); ++failed; continue;}
		sscanf(duration, "%d:%d:%d.%*d", int h, int m, int s);
		int seconds = h * 3600 + m * 60 + s;
		write("%d -- %s: %s\n", seconds, fn, duration);
		tot += seconds;
	}
	write("%d -- total: %02d:%02d:%02d\n", tot,
		tot / 3600, (tot / 60) % 60, tot % 60);
	if (failed) werror("%d files failed to parse.\n", failed);
}
