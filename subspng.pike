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
		"-map", "[v]", "-c:v", "png", "-f", "image2pipe", "pipe:3",
	}), (["fds": pipes->pipe(Stdio.PROP_IPC)]));
	int frm = 0, transcribed = 0, dupcnt = 0;
	array(string) prev = ({0}) * sizeof(pipes); //Retain the most recent frame from each pipe to detect duplicates
	string curtext = ""; int startframe;
	int halt = 0; signal(2, lambda() {halt = 1; catch {proc->kill(2);};});
	while (!halt)
	{
		string png = read_png(pipes[0]);
		if (!png) break;
		++frm;
		if (png == prev[0]) {++dupcnt; continue;} //Duplicate frame (there'll be lots of these)
		prev[0] = png;
		++transcribed;
		mapping rc = Process.run(({"tesseract", "stdin", "stdout", "-l" + lang}), (["stdin": png]));
		if (String.trim(rc->stdout) == curtext) continue; //The image is different but the transcription is the same.
		if (curtext != "")
		{
			//Complete line of subtitles! (Ignore silence, it doesn't need to be output.)
			write("[%d-%d] %s\n", startframe, frm - 1, curtext);
		}
		curtext = String.trim(rc->stdout); startframe = frm;
	}
	write("\n\nTotal frames: %d\nTranscribed: %d\nIgnored duplicate frames: %d\n\n", frm, transcribed, dupcnt);
	proc->wait();
}
