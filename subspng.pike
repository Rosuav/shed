string read_png(Stdio.File pipe)
{
	string png = pipe->read(8);
	if (!png || png == "") return 0; //Done!
	if (png != "\x89PNG\r\n\x1A\n") {werror("Bad header %O\n", png); return 0;}
	//Gather chunks till we find IEND
	while (1)
	{
		sscanf(pipe->read(4), "%4c", int size);
		string type = pipe->read(4);
		//werror("Chunk %s size %d\n", type, size);
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

mapping(int:float) frame_times = ([]);

void watch_stderr(object pipe)
{
	string buf = "";
	while (1)
	{
		string data = pipe->read(256, 1);
		if (!data || data == "") break;
		buf += data;
		while (sscanf(buf, "%s\n%s", string line, buf) == 2)
		{
			//Possibly-interesting line of output
			if (sscanf(line, "[Parsed_showinfo_0 @ 0x%*x] n:%d pts:%*d pts_time:%f", int frame, float time) && time)
			{
				frame_times[frame] = time;
				continue;
			}
			if (has_prefix(line, "[Parsed_showinfo_0 @ ")) continue;
			werror(line + "\n"); //Optionally emit all unknown lines
		}
		//Handle status lines by passing them straight through to our own stderr
		while (sscanf(buf, "%s\r%s", string line, buf) == 2)
			werror(line + "\r");
	}
}

string srttime(float tm)
{
	if (!tm) return "*ERROR*"; //Let it get written out, but with an obvious marker
	int min = (int)(tm / 60);
	return replace(sprintf("%02d:%02d:%06f", min / 60, min % 60, tm % 60), ".", ",");
}

int main(int argc, array(string) argv)
{
	if (argc < 4) exit(0, "USAGE: pike %s filename lang track [track...]\n");
	string fn = argv[1];
	string lang = argv[2];
	array(string) substrack = argv[3..];

	array pipes = (({Stdio.File}) * sizeof(substrack))();
	object stderr = Stdio.File();
	array args = ({
		"/home/rosuav/ffmpeg-git-20200617-amd64-static/ffmpeg", //Newer FFMPEG than the system one
		"-i", fn,
		"-filter_complex", sprintf(
			//Set up a black background by taking the video track and covering it.
			//This also grabs frame timings via showinfo,
			"[0:v]showinfo, drawbox=c=black:t=fill, split"
			"%{[black%s]%}"
			"%<{; [black%s][0:s:%<s]overlay=shortest=1[v%<s]%}",
			substrack)
	});
	foreach (substrack; int i; string t) args += ({"-map", "[v" + t + "]", "-c:v", "png", "-f", "image2pipe", "pipe:" + (i+3)});
	object proc = Process.create_process(args, (["fds": pipes->pipe(Stdio.PROP_IPC), "stderr": stderr->pipe(Stdio.PROP_IPC)]));
	int frm = 0, transcribed = 0, dupcnt = 0;
	array(string) prev = ({0}) * sizeof(pipes); //Retain the most recent frame from each pipe to detect duplicates
	string curtext = ""; int startframe;
	Thread.Thread(watch_stderr, stderr);
	int halt = 0; signal(2, lambda() {halt = 1; catch {proc->kill(2);};});
	array subs = ({ });
	while (!halt)
	{
		string png = read_png(pipes[0]);
		if (!png) break;
		read_png(pipes[1..][*]); //Discard for now
		++frm;
		if (png == prev[0]) {++dupcnt; continue;} //Duplicate frame (there'll be lots of these)
		prev[0] = png;
		++transcribed;
		mapping rc = Process.run(({"tesseract", "stdin", "stdout", "-l" + lang}), (["stdin": png]));
		string txt = String.trim(utf8_to_string(rc->stdout));
		if (txt == curtext) continue; //The image is different but the transcription is the same.
		if (curtext != "")
		{
			//Complete line of subtitles! (Ignore silence, it doesn't need to be output.)
			werror("[%d-%d] %s\e[K\n", startframe, frm - 1, curtext);
			subs += ({ ({startframe, frm - 1, curtext}) });
		}
		curtext = txt; startframe = frm;
	}
	if (curtext != "") subs += ({ ({startframe, frm - 1, curtext}) });
	werror("\n\nTotal frames: %d\nTranscribed: %d (%d%%)\nIgnored duplicate frames: %d\n\n",
		frm, transcribed, transcribed * 100 / (frm || 1), dupcnt);
	proc->wait();
	werror("Parsed %d timestamps.\n", sizeof(frame_times));
	//In theory, some of this could be done earlier, as long as the corresponding frame
	//times have been parsed. Since stderr parsing is asynchronous, it's easiest to just
	//do all the output after ffmpeg has terminated.
	foreach (subs, [int start, int end, string text])
	{
		write("%s --> %s\n%s\n\n", srttime(frame_times[start]), srttime(frame_times[end]), string_to_utf8(text));
	}
}
