#!/usr/local/bin/pike

void run_backup()
{
	object tottm=System.Timer();
	int totwritten=0;
	for (int i=1;i<20;++i) //Cap it at 20 to prevent a degenerate state
	{
		object tm=System.Timer();
		string stderr="";
		string fn="bup_"+i;
		int target=file_stat(fn)?->size/1048576;
		Stdio.File out=Stdio.File(fn,"wct");
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
		out->close();
		if (file_stat(fn)->size!=written) werror("\e[1;33mFile is %d bytes long but we wrote %d bytes!!\e[0m\n",file_stat(fn)->size,written);
		if (stderr=="Bad index\n") break;
		float t=tm->peek(); written/=1048576; totwritten+=written;
		write("Section %d: %dMB in %fs - %f MB/s\n",i,written,t,written/t);
	}
	float t=tottm->peek();
	write("Fetched %dMB in in %f seconds, avg throughput %f MB/s.\n",totwritten,t,totwritten/t);
}

int main(int argc,array(string) argv)
{
	if (argc>1 && argv[1]=="now") run_backup();
	//Handball back and forth with at.pike to reschedule ourselves.
	exece(combine_path(@explode_path(__FILE__)[..<1],"at.pike"),({"5:00",argv[0],"now"}));
}
