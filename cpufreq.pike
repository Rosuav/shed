//Show stats about CPU frequencies
//The maximum frequency is always shown instantaneously, with the current frequency being averaged
//over a few seconds to improve stability.
//For simplicity's sake, the values for all CPUs can be summed. This does not necessarily reflect
//real usage and effectiveness, as different CPUs/cores may have different actual performance, and
//on a mostly-idle system there will often be a number of cores at their minimum, so this is mostly
//for a busy system.
//Showing the stats "above minimum" will better reflect usage in a mostly-idle system, but may distort
//the actual values when under load.

int avg_array(array(int) n) {return `+(@n) / sizeof(n);}

string hertz(int khz) {
	if (khz < 1024) return sprintf("%d KHz", khz);
	if (khz < 1048576) return sprintf("%.2f MHz", khz / 1024.0);
	return sprintf("%.2f GHz", khz / 1048576.0);
}

int main(int argc, array(string) argv) {
	mapping args = Arg.parse(argv);
	array cpus = glob("cpu[0-9]*", get_dir("/sys/devices/system/cpu"));
	int CPUSIZE = sizeof((string)sizeof(cpus));
	array order = (array(int))(cpus[*] - "cpu");
	sort(order, cpus);
	array paths = sprintf("/sys/devices/system/cpu/%s/cpufreq/", cpus[*]);
	array past_stats = ({ });
	while (1) {
		array max = (array(int))Stdio.read_file((paths[*] + "scaling_max_freq")[*]);
		array min = allocate(sizeof(cpus));
		if (args->abovemin) min = (array(int))Stdio.read_file((paths[*] + "scaling_min_freq")[*]);
		array cur = (array(int))Stdio.read_file((paths[*] + "scaling_cur_freq")[*]);
		if (args->combine) {
			max = ({`+(@max)});
			min = ({`+(@min)});
			cur = ({`+(@cur)});
		}
		past_stats = past_stats[<3..] + ({cur});
		cur = avg_array(Array.transpose(past_stats)[*]);
		if (!args->combine) {
			write("\e[2J\e[0;0H");
			foreach (min; int i; int m)
				write("[%" + CPUSIZE + "d] %5.2f%% of max freq %s\n", i + 1, (cur[i] - m) * 100.0 / (max[i] - m), hertz(max[i] - m));
		}
		if (args->combine || args->summarize) {
			int totcur = `+(@cur), totmin = `+(@min), totmax = `+(@max);
			write("%s%5.2f%% of max freq %s%s",
				args->summarize ? "\nTotal: " : "",
				(totcur - totmin) * 100.0 / (totmax - totmin),
				hertz(totmax - totmin),
				args->combine ? "\e[J\r" : "\n",
			);
		}
		sleep(1);
	}
}
