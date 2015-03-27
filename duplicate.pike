#!/usr/bin/env pike
int main(int argc,array(string) argv)
{
	string src=argv[1],dst=argv[2];
	mkdir(dst);
	foreach (get_dir(src),string n)
	{
		object stat=file_stat(src+"/"+n,1);
		if (!stat) {write("??? %O\n",n); continue;}
		//Three possibilities. Directories get made and bind-mounted;
		//files get hard-linked; symlinks get skipped, because I don't
		//know what to do with those.
		if (stat->islnk) continue; //TODO.
		if (stat->isdir)
		{
			mkdir(dst+"/"+n);
			Process.create_process(({"sudo","mount","--bind",src+"/"+n,dst+"/"+n}))->wait();
		}
		else
		{
			if (!file_stat(dst+"/"+n)) hardlink(src+"/"+n,dst+"/"+n);
		}
	}
}

