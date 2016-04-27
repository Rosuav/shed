void gotbytes(mixed id, string(8bit) bytes)
{
	if (sizeof(bytes)==44) return; //RIFF WAVE header
	//write("Got %d bytes\n", sizeof(bytes));
	constant sec_length = 25;
	string msg = "";
	foreach (bytes/25, string section)
	{
		int tot = `+(@(array)section)/sec_length;
		tot = abs(tot-128);
		//So we now have a number from 0 to 128 indicating how much oomph the microphone saw.
		if (catch {msg += ({" ","-","─","━","═","╦","╬","█","█"})[tot/16];}) write("OOOOOOOOOOOPS! %d OOOOOOOPS!",tot);
	}
	write(msg);
}

int main()
{
	write("%d\n", sizeof(" -─━═╦╬█"));
	object stdout = Stdio.File();
	object proc = Process.create_process(({"arecord", "-r", "2000"}), (["stdout": stdout->pipe()]));
	signal(signum("SIGINT"), lambda() {proc->kill(2); exit(0);});
	stdout->set_read_callback(gotbytes);
	return -1;
}
