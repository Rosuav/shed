string read_png(Stdio.File pipe)
{
	string png = pipe->read(8);
	if (!png || png == "") return 0; //Done!
	if (png != "\x89PNG\r\n\x1A\n") {write("Bad header %O\n", png); return 0;}
	//Gather chunks till we find IEND
	while (1)
	{
		sscanf(pipe->read(4), "%4c", int size);
		string type = pipe->read(4);
		//write("Chunk %s size %d\n", type, size);
		string data = "";
		while (sizeof(data) < size)
		{
			string cur = pipe->read(size);
			if (!cur || cur == "") break; //Read error
			data += cur;
		}
		string crc = pipe->read(4);
		png += sprintf("%4c%s%s%s", size, type, data, crc);
		if (type == "IEND") break;
	}
	return png;
}
int main(int argc, array(string) argv)
{
	if (argc < 4) exit(0, "USAGE: pike %s filename lang track [track...]\n");
	string fn = argv[1];
	string lang = argv[2];
	string substrack = argv[3]; //TODO: Support multiple

	array pipes = ({Stdio.File()});
	object proc = Process.create_process(({
		"/home/rosuav/ffmpeg-git-20200617-amd64-static/ffmpeg", //Newer FFMPEG than the system one
		"-y", "-i", fn, //Need -y so it'll "overwrite" the pipe
		"-filter_complex", "[0:v]drawbox=c=black:t=fill[black]; [black][0:s:" + substrack + "]overlay=shortest=1[v]",
		"-map", "[v]", "-c:v", "png", "-f", "image2pipe", "/dev/fd/3",
	}), (["fds": pipes->pipe(Stdio.PROP_IPC)]));
	int frm = 0, transcribed = 0, smallcnt;
	string prev, smallest; //Save two PNG image blobs and ignore any that match
	string prevtext;
	while (1)
	{
		string png = read_png(pipes[0]);
		if (!png) break;
		//write("-- end of PNG file --\n");
		//write("%O\n", Image.PNG.decode(png));
		++frm;
		if (!prev) prev = smallest = png;
		else if (png == prev) continue; //Duplicate frame
		else if (png == smallest) {++smallcnt; continue;} //Probably an empty frame
		else if (sizeof(png) < sizeof(smallest)) smallest = png; //Recognize an empty frame by its data size
		prev = png;
		++transcribed;
		mapping rc = Process.run(({"tesseract", "stdin", "stdout", "-l" + lang}), (["stdin": png]));
		if (rc->stdout != "" && rc->stdout != prevtext) write("[%d] Subs: %s\n", frm, prevtext = rc->stdout);
	}
	write("\n\nTotal frames: %d\nTranscribed: %d\nIgnored b/c smallest: %d\n", frm, transcribed, smallcnt);
	proc->wait();
}
