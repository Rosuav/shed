//Run this in a repo to find the largest block of oldest code
//TODO: Filter `git ls-files` down to just text files, as the output is
//not particularly helpful with binary files.
//Lines are scored by their age in seconds (difference between author-time and
//current time()), and blocks with the same origin hash are scored by the line
//time multiplied by the size of the block.
//Any arguments given get passed to 'git ls-files', so you can restrict the set
//of files searched by glob or to explicit files.

int verbose=1; //TODO: Turn this off if stdout is not a TTY
int statuslen=0;
void status(string msg)
{
	if (!verbose) return;
	write("%s\r%s\r"," "*statuslen,msg);
	statuslen=sizeof(msg);
}

int main(int argc,array(string) argv)
{
	int tm=time(); //Use a consistent snapshot of time
	mapping(string:mapping) commits=([]);
	int oldest; string olddesc;
	foreach (Process.run(({"git","ls-files","-z"})+argv[1..])->stdout/"\0"-({""}),string fn)
	{
		status("Checking "+fn+"...");
		array(string) lines=Process.run(({"git","blame","--porcelain",fn}))->stdout/"\n";
		if (lines[-1]=="") lines=lines[..<1];
		string curhash; int curblock; int startline;
		for (int i=0;i<sizeof(lines);++i) //Don't directly iterate over lines - we may need to snag more lines during the loop
		{
			sscanf(lines[i],"%[0-9a-f] %d %d %d",string hash,int origline,int finalline,int blocksize);
			if (lines[i+1][0]!='\t')
			{
				mapping metadata=([]);
				while (lines[i+1][0]!='\t') {sscanf(lines[++i],"%s %s",string key,string val); metadata[key]=val;}
				metadata->age=tm-(int)metadata["author-time"];
				commits[hash]=metadata;
			}
			//assert commits[hash]; //If the info block is absent (the header is followed immediately by the line itself), we should have already seen this commit hash.
			if (sizeof(String.trim_all_whites(lines[++i]))<4) continue; //Ignore short lines (note that trimming all whites also trims off the identifying \t)
			if (hash!=curhash)
			{
				if (curblock>oldest)
				{
					//It's a new largest/oldest block. Note that this assumes that lines are consecutive,
					//which may not be quite correct as short lines are skipped.
					oldest=curblock;
					olddesc=sprintf("%s:%d\n%[0]s:%d\n%dish lines from %s authored %s",fn,startline,finalline-1,finalline-startline,curhash,ctime((int)commits[curhash]["author-time"]));
				}
				curblock=0; curhash=hash; startline=finalline;
			}
			curblock+=commits[hash]->age;
		}
	}
	status("");
	write("Largest/oldest block:\n%s\n",olddesc||"(none!)");
}
