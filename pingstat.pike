/* Run ping, and give stats.

Every time a line comes in that looks like a response, it will add to the
success count. At the bottom of the display, estimates will be given for
the average success rate, giving averages that roll approximately every
1, 5, 15, 60, 1440, and 10080 minutes (hour, day, and week).

Note that the success count is defined as responses per second, and will
scale higher or lower if ping's "-i" parameter is given.

Additionally, any line that does NOT look like a response, and any text
on stderr, will be coloured in red. This works well with the -O parameter
to ping, which will emit a line "no answer yet for icmp_seq=10004" any
time a ping times out.

Note that the timing starts with the first successful response, and any
additional successes within the first eighth of a second will be ignored.
This is fairly arbitrary, but gives decent results in practice.
*/

void bad_line(string line) {
	//TODO: Figure out if the terminal supports colour
	write("\e[1;31m%s\e[0m\e[K\n", line);
}

object runtime = System.Timer();
array(float) periods = ({10.0, 60.0, 300.0, 900.0, 3600.0, 86400.0, 604800.0});
array(float) averages = ({0.0}) * sizeof(periods);
float last_weight = 0.0;
void update_averages(int|float add) {
	float t = runtime->peek();
	if (t < 0.125) return;
	float delta = t - last_weight;
	string msg = "";
	foreach (periods; int i; float p) {
		float d = min(delta, p);
		averages[i] = (averages[i] * (min(last_weight + d, p) - d) + add) / min(t, p);
		//if (t < p / 2) continue; //Hide the ones that aren't interesting yet
		int pct = (int)(averages[i] * 100.0);
		if (pct < 0) msg += " --";
		else if (pct >= 100) msg += " OK";
		else msg += " " + pct;
	}
	write("Avg:%s (%.0fs)\e[K\r", msg, t);
	last_weight = t;
}

string stdout_buf = "", stderr_buf = "";
int seen_good = 0;
void got_stdout(string data) {
	stdout_buf += data;
	while (sscanf(stdout_buf, "%s\n%s", string line, stdout_buf) == 2) {
		if (sscanf(line, "%*d bytes from %*s: icmp_seq=%*d ttl=%*d time=%f ms", float tm) == 5) {
			//TODO: Optionally show the time instead of a packet count
			write("%s\e[K\n", line);
			if (seen_good) update_averages(1);
			else {seen_good = 1; runtime->get();}
			continue;
		}
		bad_line(line);
		if (seen_good) update_averages(0);
	}
}
void got_stderr(string data) {
	stderr_buf += data;
	while (sscanf(stderr_buf, "%s\n%s", string line, stderr_buf) == 2)
		bad_line(line);
}

int main(int argc, array(string) argv) {
	return Process.run(({"ping"}) + argv[1..], (["stdout": got_stdout, "stderr": got_stderr]))->exitcode;
}
