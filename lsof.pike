//Sometimes the builtin lsof gets stuck, so here's a much much simpler thing that can search for
//a specific prefix.

int main(int argc, array(string) argv) {
	mapping args = Arg.parse(argv);
	string search = (args[Arg.REST] + ({""}))[0];
	//Sort numerically for the benefit of the human
	foreach (sort((array(int))get_dir("/proc") - ({0})), int pid) {
		string dir = "/proc/" + pid + "/fd/";
		array files = get_dir(dir) || ({ }); //If the process has terminated before we get here, nothing to do
		foreach (sort((array(int))files), int fd) catch {
			string dest = readlink(dir + fd);
			if (has_prefix(dest, search)) {
				if (args->pid) write("%d\n", pid); //PID only
				else if (args->exe) {
					//Reading the executable might fail.
					string exe = "<unknown>";
					catch {exe = readlink("/proc/" + pid + "/exe");};
					write("%d: %s\n", pid, exe);
				}
				else write("%d: %s\n", pid, dest);
			}
		};
	}
}
