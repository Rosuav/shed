int main(int argc, array(string) argv) {
	if (argc < 3) exit(1, "USAGE: pike %s glob command\nWatches matching files in the current directory, runs command on change.\nExample: pike %<s '*.ly' make\n", argv[0]);
	string filespec = argv[1];
	array cmd = argv[2..]; //TODO: Support a filename marker in the args
	object inot = System.Inotify.Instance();
	inot->add_watch(".", System.Inotify.IN_CLOSE_WRITE | System.Inotify.IN_MOVED_TO | System.Inotify.IN_MOVED_FROM) {
		[int event, int cookie, string path] = __ARGS__;
		switch (event) {
			case System.Inotify.IN_CLOSE_WRITE:
			case System.Inotify.IN_MOVED_TO:
				if (glob(filespec, path)) Process.create_process(cmd);
		}
	};
	inot->set_nonblocking();
	return -1;
}
