int main()
{
	string lastspd;
	while (1)
	{
		string spd=Process.run(({"cpufreq-info","-c","0","-fm"}))->stdout;
		if (spd!=lastspd) write("%s %s",String.trim_all_whites(lastspd=spd),ctime(time()));
		sleep(1);
	}
}

