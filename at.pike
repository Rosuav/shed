#!/usr/local/bin/pike

int main(int argc,array(string) argv)
{
	if (argc<3) exit(1,"USAGE: %s time command [args...]\nExecutes command at time, with tick-down display.\n",argv[0]);
	int usetitle = argv[1] == "--title"; argv -= ({"--title"});
	sscanf(argv[1], "%d:%d", int hr, int min);
	while (1)
	{
		//Delay a bit and then redisplay the time. Recalculates every iteration for safety.
		mapping tm=localtime(time());
		int cur=tm->hour*3600+tm->min*60+tm->sec;
		int secs=(hr*3600+min*60) - cur;
		//Note that the effect of these two conditions is that times past midnight
		//work as expected, but the script depends on waking up within the last
		//minute of the delay. If anything goes wrong with the sleep at that last
		//minute, an extra day will be added on. This is not considered to be a
		//particularly serious scenario, as this script - unlike the more common
		//scheduling tools - is designed for human interactive use, not unattended
		//automation, and should not have to cope with all those issues.
		if (secs<0) secs+=86400;
		if (secs<=60)
		{
			if (usetitle) write("\033]0;%d\a", secs);
			write("Sleeping %d seconds until %02d:%02d\n",secs,hr,min);
			sleep(secs);
			//Try an exec first. If that succeeds, great! But it doesn't search paths (it's not
			//execp() family), so it'll fail if the full path isn't provided.
			exece(argv[2],argv[3..]);
			//Fall back on launching a subprocess. This *does* do an execp() family call, so you
			//can say "pike at 14:55 vlc Music/Alice.mp3" and it'll find /usr/bin/vlc to execute.
			//Note that if we absolutely had to exec here (if we promised to maintain the PID,
			//for instance), we could probably shell out to /usr/bin/which on the first arg and
			//then retry the exec. But it's probably not worth it.
			exit(Process.create_process(argv[2..])->wait());
		}
		string timeleft = secs >= 3600 ? sprintf("%d:%02d:%02d", secs/3600, (secs/60)%60, secs%60)
			: sprintf("%02d:%02d", secs/60, secs%60);
		if (usetitle) write("\033]0;%s\a", timeleft);
		write("Sleeping %s until %02d:%02d \r", timeleft, hr, min);
		sleep(secs%60 || 60); //Try to get the "time to launch" to an exact number of minutes
	}
}
