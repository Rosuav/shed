/* All windows on the second monitor should exist on all desktops.

Effectively, with this active, workspace switching applies only to the primary
monitor, and not to the second. In order to do this, it needs to know the size
of the primary monitor; this is presumed to be the width of any instance of an
xfce4-panel, calculated on startup. As long as you have at least one panel the
full width of your primary monitor, this will work (even if your primary isn't
the left-most monitor).
*/

int monitor_left = 1<<32, monitor_right;
multiset(int) stickied = (<>);

void poll()
{
	call_out(poll, 15);
	sscanf(Process.run(({"wmctrl", "-lG"}))->stdout,"%{0x%8x %d %d %d %d %d%*[ ]%*[^ ] %s\n%}", array info);
	if (!monitor_right)
	{
		//First, zip through and find xfce4-panel, and grab the widest dimensions.
		//This assumes that the user is running a panel that takes up the entire
		//primary monitor; currently, I don't know of any better way to get this.
		//Note that monitor_left may well be zero, but monitor_right shouldn't be.
		foreach (info, array row) if (row[-1] == "xfce4-panel")
		{
			monitor_left = min(monitor_left, row[2]);
			monitor_right = max(monitor_right, row[2]+row[4]);
		}
		write("Primary monitor span: %d-%d\n", monitor_left, monitor_right);
	}
	foreach (info, [int id, int desktop, int x, int y, int w, int h, string title])
	{
		//Note that "being on the primary monitor" is defined by the left edge
		//of the window. Spanning monitors (or just straying a little past the
		//edge) does not affect a window's stickiness.
		int on_primary = (x >= monitor_left && x < monitor_right);
		if (!on_primary && desktop >= 0)
		{
			//This window is past the edge and isn't stickied already.
			stickied[id] = 1;
			Process.create_process(({"wmctrl", "-ir", (string)id, "-b", "add,sticky"}))->wait();
		}
		else if (on_primary && stickied[id])
		{
			//A window that we stickied has been brought back onto the main monitor.
			stickied[id] = 0;
			Process.create_process(({"wmctrl", "-ir", (string)id, "-b", "remove,sticky"}))->wait();
		}
		//If we spot an OBS projector, full-screen it. (Once fullscreened, it should be in (0,0), so don't re-fs it.)
		if (title == "Windowed Projector (Preview)" && (x || y))
		{
			Process.create_process(({"wmctrl", "-ir", (string)id, "-e", "0,0,0,-1,-1"}))->wait();
			Process.create_process(({"wmctrl", "-ir", (string)id, "-b", "add,fullscreen"}))->wait();
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
Description=Stickify windows on secondary monitors

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
