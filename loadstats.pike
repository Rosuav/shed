//Show CPU/GPU load on stream
#charset utf-8

array(int) cputime() {
	sscanf(Stdio.read_file("/proc/stat"), "cpu %d %d %d %d", int user, int nice, int sys, int idle);
	return ({user + nice + sys + idle, idle});
}

int main() {
	//string spinner = "⠇⡆⣄⣠⢰⠸⠙⠋";
	string spinner = "⠇⠦⠴⠸⠙⠋";
	int spinnerpos = 0;
	[int lasttot, int lastidle] = cputime();
	while (1) {
		sleep(0.25);
		mapping proc = Process.run(({"nvidia-settings", "-t",
			"-q:0/VideoEncoderUtilization",
			"-q:0/VideoDecoderUtilization",
			"-q:0/GPUUtilization",
		}));
		sscanf(proc->stdout, "%d\n%d\ngraphics=%d, memory=%d", int enc, int dec, int gpu, int vram);
		[int tot, int idle] = cputime();
		if (tot == lasttot) --lasttot; //Prevent division by zero
		string msg = sprintf("CPU %d%% GPU %d%% VRAM %d%% Enc %d%%:%d%% %c",
			100 - 100 * (idle - lastidle) / (tot - lasttot),
			gpu, vram, enc, dec,
			spinner[spinnerpos++ % sizeof(spinner)]
		);
		werror("%s   \r", msg);
		Protocols.HTTP.post_url("https://sikorsky.rosuav.com/admin", Standards.JSON.encode(([
			"cmd": "send_message",
			"channel": "#rosuav",
			"msg": (["dest": "/set", "target": "loadstats", "message": msg]),
		])), (["Content-Type": "application/json"]));
	}
}
