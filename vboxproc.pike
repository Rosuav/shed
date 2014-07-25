//Enumerate VirtualBox processes and which VM they're running
//Extracts info solely from /proc/*/cmdline
//Useful for figuring out which VM is taking all the CPU, as the
//default display in 'top' shows only VirtualBox, and the full
//command line is incredibly verbose.

int main()
{
	foreach (get_dir("/proc"),string n) if ((string)(int)n==n) catch
	{
		string cmd=Stdio.read_file("/proc/"+n+"/cmdline");
		if (!cmd) continue;
		array args=cmd/"\0";
		if (args[0]!="/usr/lib/virtualbox/VirtualBox") continue; //TODO: How do I properly detect this path? It's not `which VirtualBox`.
		foreach (args;int i;string arg) if (arg=="--comment") write("%5s %s\n",n,args[i+1]);
	};
}

