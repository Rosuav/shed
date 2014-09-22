int main(int argc,array(string) argv)
{
	if (argc<3) exit(1,"USAGE: %s time command [args...]\nExecutes command at time.\n",argv[0]);
	sscanf(argv[1],"%d:%d",int hr,int min);
	while (1)
	{
		//Delay a bit and then redisplay the time. Recalculates every iteration for safety.
		mapping tm=localtime(time());
		int cur=tm->hour*3600+tm->min*60+tm->sec;
		int secs=(hr*3600+min*60) - cur;
		if (secs<0) secs+=86400;
		if (secs<=60)
		{
			write("Sleeping %d seconds until %02d:%02d\n",secs,hr,min);
			sleep(secs);
			exit(Process.create_process(argv[2..])->wait()); //It's either that or exece() and simulate path searching. This does an execp() family call.
		}
		write("Sleeping %02d:%02d until %02d:%02d \r",secs/60,secs%60,hr,min);
		sleep(secs%60 || 60); //Try to get the "time to launch" to an exact number of minutes
	}
}
