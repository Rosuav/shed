//Simple and naive file sync tool - not a replacement for rsync.
//Looks ONLY at file names, and only one direction; if a file exists
//on the client and not on the server, it gets sent to the server.

constant PORT = 2222;

//Modified version of Tools.Install.ProgressBar
//The original uses too many private members and can't usefully be
//subclassed.

//! A class keeping some methods and state to conveniently render
//! ASCII progress bars to stdout.
class TimedProgressBar
{
  private int width = 45;

  private float phase_base, phase_size;
  private int max, cur;
  private string name;
  private int starttime;

  //! Change the amount of progress without updating on stdout.
  void set_current(int _cur)
  {
    cur = _cur;
  }

  //! Change the name of the progress bar without updating on stdout.
  void set_name(string _name)
  {
    name = _name;
  }

  //!
  void set_phase(float _phase_base, float _phase_size)
  {
    phase_base = _phase_base;
    phase_size = _phase_size;
  }

  //! Write the current look of the progressbar to stdout.
  //! @param increment
  //!   the number of increments closer to completion since last call
  //! @returns
  //!   the length (in characters) of the line with the progressbar
  int update(int increment)
  {
    cur += increment;
    cur = min(cur, max);

    float ratio = phase_base + ((float)cur/(float)max) * phase_size;
    if(1.0 < ratio)
      ratio = 1.0;

    int bar = (int)(ratio * (float)width);
    int is_full = (bar == width);

    // int spinner = (max < 2*width ? '=' : ({ '\\', '|', '/', '-' })[cur&3]);
    int spinner = '=';

    string timeleft = "";
    float timespent = time(starttime);
    if (timespent >= 5.0) //Don't show stats until we've been going a few seconds
    {
        int t = (int)(timespent * (1.0 - ratio) / ratio);
	if (t <= 0) timeleft = "0s";
        else if (t < 60) timeleft = t + "s...";
        else if (t < 3600) timeleft = sprintf("%02d:%02d...", t/60, t%60);
        else if (t < 86400) timeleft = sprintf("%d:%02d:%02d...", t/3600, (t%3600)/60, t%60);
        else timeleft = sprintf("%d days, %d:%02d:%02d...", t/86400, (t%86400)/3600, (t%60)/60, t%60);
    }

    return write("\r   %-13s |%s%c%s%s %4.1f %% %s  ",
		 name+":",
		 "="*bar,
		 is_full ? '|' : spinner,
		 is_full ? "" : " "*(width-bar-1),
		 is_full ? "" : "|",
		 100.0 * ratio,
                 timeleft) - 1;
  }

  //! @decl void create(string name, int cur, int max, float|void phase_base,@
  //!                   float|void phase_size)
  //! @param name
  //! The name (printed in the first 13 columns of the row)
  //! @param cur
  //! How much progress has been made so far
  //! @param max
  //! The amount of progress signifying 100% done. Must be greater than zero.
  void create(string _name, int _cur, int _max,
	      float|void _phase_base, float|void _phase_size)
  {
    name = _name;
    max = _max;
    cur = _cur;
    starttime = time();

    phase_base = _phase_base || 0.0;
    phase_size = _phase_size || 1.0 - phase_base;
  }
}
// End modified Tools.Install.ProgressBar

//Converse of sock->write("%"+sz+"H", data)
string(0..255) read_hollerith(Stdio.File sock, int sz)
{
	string data = "";
	while (sizeof(data) < sz)
	{
		string cur = sock->read(sz - sizeof(data));
		if (cur == "") return 0;
		data += cur;
	}
	sscanf(data, "%" + sz + "c", sz);
	data = "";
	while (sz > 0)
	{
		string cur = sock->read(sz);
		if (cur == "") return 0;
		data += cur; sz -= sizeof(cur);
	}
	return data;
}

int main(int argc, array(string) argv)
{
	if (argc == 1)
	{
		//Server mode
		string findcmd = "find -type f -print0"; //Run on both client and server to produce a list of file names
		Stdio.Port port = Stdio.Port(PORT);
		while (Stdio.File sock = port->accept())
		{
			write("Received connection from %s\n", sock->query_address());
			sock->write("%2H", findcmd);
			sock->write("%4H", Process.run(findcmd)->stdout);
			int n = 0;
			while (1)
			{
				string fn = read_hollerith(sock, 2);
				if (!fn) break;
				if (fn == "")
				{
					//Clean termination.
					sock->write("%2H", "Received " + n + " files.");
					break;
				}
				string data = read_hollerith(sock, 4);
				if (!data) break;
				array(string) parts = explode_path(fn) - ({"."});
				for (int i = 0; i < sizeof(parts) - 1; ++i)
					mkdir(combine_path(@parts[..i]));
				if (file_stat(fn)) continue; //Ignore files that already exist.
				Stdio.write_file(fn, data);
				++n;
			}
			sock->close();
		}
		return 0;
	}
	//Client mode
	Stdio.File sock = Stdio.File();
	write("Connecting to %s...\n", argv[1]);
	sock->connect(argv[1], PORT);
	string findcmd = read_hollerith(sock, 2);
	array(string) clientfiles = Process.run(findcmd)->stdout / "\0";
	write("Getting server files...\n");
	array(string) serverfiles = read_hollerith(sock, 4) / "\0";
	write("Client has %d files, server has %d\n", sizeof(clientfiles), sizeof(serverfiles));
	array(string) sendme = clientfiles - serverfiles;
	int totsize = 0; foreach (sendme, string fn) totsize += file_stat(fn)->size;
	write("Need to send: %d files, %d bytes\n", sizeof(sendme), totsize); //May have more elements than the raw numbers suggest
	object prog = TimedProgressBar("Transferring", 0, totsize);
	prog->update(0);
	foreach (sendme, string fn)
	{
		if (fn == "") continue;
		write("%d - %s\e[K", file_stat(fn)->size, fn[..64]);
		sock->write("%2H", fn);
		sock->write("%4H", Stdio.read_file(fn));
		prog->update(file_stat(fn)->size);
	}
	write("\e[K\n"); //Move off the progress bar
	sock->write("%2H", "");
	string signoff = read_hollerith(sock, 2);
	write("Server says: %s\n", signoff);
}
