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
	int threshold = 20; //Number of frames of silence before the next subs track will be checked

	array pipes = (({Stdio.File}) * sizeof(substrack))();
	object stderr = Stdio.File();
	array args = ({
		"/home/rosuav/ffmpeg-git-20200617-amd64-static/ffmpeg", //Newer FFMPEG than the system one
		"-i", fn,
		"-filter_complex", sprintf(
			//Set up a black background by taking the video track and covering it.
			//This also grabs frame timings via showinfo,
			"[0:v]showinfo, drawbox=c=black:t=fill, split=%d"
			"%{[black%s]%}"
			"%<{; [black%s][0:s:%<s]overlay=shortest=1[v%<s]%}",
			sizeof(substrack), substrack)
	});
	foreach (substrack; int i; string t) args += ({"-map", "[v" + t + "]", "-c:v", "png", "-f", "image2pipe", "pipe:" + (i+3)});
	//werror("Args: %O\n", args);
	object proc = Process.create_process(args, (["fds": pipes->pipe(Stdio.PROP_IPC), "stderr": stderr->pipe(Stdio.PROP_IPC)]));
	int frm = 0, transcribed = 0, dupcnt = 0;
	array(string) prev = ({0}) * sizeof(pipes); //Retain the most recent frame from each pipe to detect duplicates
	string curtext = ""; int startframe, source;
	Thread.Thread(watch_stderr, stderr);
	int halt = 0; signal(2, lambda() {halt = 1; catch {proc->kill(2);};});
	array subs = ({ });
	array(int) silence = ({threshold}) * sizeof(substrack);
	while (!halt)
	{
		array(string) frames = read_png(pipes[*]);
		if (has_value(frames, 0)) break; //Most likely, EOF will be signalled by an entire array of zeroes
		//If first one translates to "", increment silence[0]. If silence[0] >= threshold,
		//OCR the second, and so on. Zero out the silence marker when we have nonsilence.
		//It might be worth zeroing out all future silence markers too, but not worth it -
		//it won't make any practical difference, far as I know.
		++frm;
		foreach (frames; int i; string png)
		{
			if (png == prev[i])
			{
				//Duplicate frame (there'll be lots of these)
				if (silence[i] && ++silence[i] >= threshold) continue; //Duplicate blank - move on to the next
				break; //Duplicate lyric or short silence - we're done.
			}
			prev[i] = png;
			++transcribed; //Yes, we could potentially transcribe multiple frames, but only if the images change while being blank
			mapping rc = Process.run(({"tesseract", "stdin", "stdout", "-l" + lang}), (["stdin": png]));
			string txt = String.trim(utf8_to_string(rc->stdout));
			if (txt == "" && silence[i]) //It's more silence, even though the image wasn't a complete duplicate
			{
				if (++silence[i] >= threshold) continue;
				break;
			}
			if (txt == curtext) break; //The image is different but the transcription is the same.
			if (curtext != "")
			{
				//Complete line of subtitles! (Ignore silence, it doesn't need to be output.)
				werror("[%d-%d %d] %s\e[K\n", startframe, frm - 1, source, replace(curtext, "\n", " "));
				subs += ({ ({startframe, frm - 1, curtext}) });
			}
			curtext = txt; startframe = frm; source = i;
			silence[i] = curtext == "";
			break;
		}
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
