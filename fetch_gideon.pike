#!/usr/local/bin/pike

int main()
{
	for (int i=1;i<20;++i) //Cap it at 20 to prevent a degenerate state
	{
		object tm=System.Timer();
		string stderr="";
		int target=file_stat("bup_"+i)?->size/1048576;
		Stdio.File out=Stdio.File("bup_"+i,"wct");
		int written=0;
		mapping rc=Process.run(
			({"ssh","dailybup@gideon",(string)i}),
			(["stdout":lambda(string x)
			{
				out->write(x);
				written+=sizeof(x);
				catch {write("%dMB/%dMB - %f MB/s    \r",written/1024/1024,target,written/1024/1024/tm->peek());}; //Ignore div by zero
			},"stderr":lambda(string x)
			{
				werror("\e[1;31m"+x+"\e[0m");
				if (sizeof(stderr)<1024) stderr+=x; //Keep stderr till the end, if it's short enough; lets us know when we're done.
			}])
		);
		if (stderr=="Bad index\n") {write("All finished!\n"); break;}
		float t=tm->peek(); written/=1048576;
		write("Section %d: %dMB in %fs - %f MB/s\n",i,written,t,written/t);
	}
}

