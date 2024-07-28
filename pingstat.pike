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
		if (pct < 0) msg += " \e[1;31m--"; //Below zero is a calculation oddity
		else if (pct < 50) msg += " \e[1;31m" + pct; //Below half is terrible!
		else if (pct < 80) msg += " \e[0;31m" + pct; //Non-bold red
		else if (pct < 90) msg += " \e[0;38;2;255;187;170m" + pct; //Orange (256 color mode)
		else if (pct < 99) msg += " \e[1;33m" + pct; //Yellow for up to 98%
		else if (pct < 100) msg += " \e[1;32m" + pct; //99% can be a rounding error, even if all's good.
		else msg += " \e[1;32mOK"; //100% and above get shown as "OK" to keep the display tidy
	}
	write("Avg:%s \e[0m(%.0fs)\e[K\r", msg, t);
	last_weight = t;
}

string stdout_buf = "", stderr_buf = "";
int seen_good = 0;
void got_stdout(mixed _, string data) {
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
void got_stderr(mixed _, string data) {
	stderr_buf += data;
	while (sscanf(stderr_buf, "%s\n%s", string line, stderr_buf) == 2)
		bad_line(line);
}

int main(int argc, array(string) argv) {
	mapping modifiers = (["stdout": got_stdout, "stderr": got_stderr]);
	object out = Stdio.File(), err = Stdio.File();
	object proc = Process.Process(({"ping"}) + argv[1..], ([
		"stdout": out->pipe(), "err": err->pipe(),
		"callback": lambda() {exit(0);},
	]));
	out->set_read_callback(got_stdout);
	err->set_read_callback(got_stderr);
	return -1;
}
