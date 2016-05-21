/* All windows on the second monitor should exist on all desktops.

Effectively, with this active, workspace switching applies only to the primary
monitor, and not to the second. In order to do this, it needs to know the size
of the primary monitor; this is presumed to be the width of any instance of an
xfce4-panel, calculated on startup.
*/

int monitor_width;
multiset(int) stickied = (<>);

void poll()
{
	call_out(poll, 60);
	sscanf(Process.run(({"wmctrl", "-lG"}))->stdout,"%{0x%8x %d %d %d %d %d%*[ ]%*[^ ] %s\n%}", array info);
	if (!monitor_width)
	{
		//First, zip through and find xfce4-panel, and grab the greatest width.
		//This assumes that the user is running a panel that takes up the entire
		//first monitor; currently, I don't know of any better way to get this.
		foreach (info, array row) if (row[-1] == "xfce4-panel")
			monitor_width = max(monitor_width, row[2]+row[4]);
		write("Monitor width: %d\n", monitor_width);
	}
	foreach (info, [int id, int desktop, int x, int y, int w, int h, string title])
	{
		if (x >= monitor_width && desktop >= 0)
		{
			//This window is past the edge and isn't stickied already.
			stickied[id] = 1;
			Process.create_process(({"wmctrl", "-ir", (string)id, "-b", "add,sticky"}))->wait();
		}
		else if (x < monitor_width && stickied[id])
		{
			//A window that we stickied has been brought back onto the main monitor.
			stickied[id] = 0;
			Process.create_process(({"wmctrl", "-ir", (string)id, "-b", "remove,sticky"}))->wait();
		}
	}
	stickied &= (multiset)info[*][0]; //Prune the list of any windows that have closed.
}

int main(int argc, array(string) argv)
{
	if (argc > 1 && argv[1]-"-" == "install")
	{
		string pike = master()->_pike_file_name; //Lifted from Hogan
		if (!has_prefix(pike, "/")) pike = Process.search_path(pike);
		Stdio.write_file("/etc/systemd/system/stickymonitor.service", sprintf(#"[Unit]
Description=Stickify windows on the second monitor

[Service]
User=%s
Environment=DISPLAY=%s
ExecStart=%s %s
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
", getenv("SUDO_USER") || "root", getenv("DISPLAY") || "", pike, argv[0]));
		Process.create_process(({"systemctl", "--system", "daemon-reload"}))->wait();
		Process.create_process(({"systemctl", "enable", "stickymonitor"}))->wait();
		Process.create_process(({"systemctl", "start", "stickymonitor"}))->wait();
		write("Installed and started.\n");
		return 0;
	}
	poll();
	return -1;
}
