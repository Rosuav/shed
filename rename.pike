//Like Process.sh_quote() but also escapes ( and )
string sh_quote(string s)
{
  return replace(s,
	({"\\", "'", "\"", " ", "(", ")"}),
	({"\\\\", "\\'", "\\\"","\\ ","\\(","\\)"}));
}

int main(int argc,array(string) argv)
{
	sscanf(Stdio.read_file("/video/Mythbusters/00index.txt"),"%{/%s\n%*s\n\n%}",array(array(string)) filenames);
	array(string) dir=filenames[*][0];
	if (argc>2)
	{
		//Local mode: rename a single file
		string fn=argv[1]; if (!file_stat(fn)) exit(1,"File not found: %s\n",fn);
		array(string) tmp=glob(argv[2]+" *",dir); if (!sizeof(tmp)) exit(1,"Not found: %s*\n",argv[2]);
		string outfn=tmp[0];
		if (!has_suffix(fn,".mkv"))
		{
			Process.create_process(({"avconv","-i",fn,outfn}))->wait();
			if (!file_stat(outfn)) exit(1,"Something went wrong in avconv, scroll up for errors\n");
			Process.create_process(({"scp",outfn,"huix:/video/Mythbusters/"}))->wait();
			if (!file_stat("/video/Mythbusters/"+outfn)) exit(1,"Something went wrong in transfer, scroll up for errors\n");
			rm(outfn);
		}
		else Process.create_process(({"scp",fn,"huix:/video/Mythbusters/"+sh_quote(outfn)}))->wait();
		exit(0,"Successfully transferred; input file can safely be removed.\n"); //Don't actually rm(fn) though, in case it's still wanted locally.
	}
	array(string) exists=get_dir("/video/Mythbusters");
	foreach (Stdio.read_file("Mythbusters episodes")/"\n"-({""}),string line) if (mixed ex=catch
	{
		[string fn,string season,string idx,string title,string notes]=(line/"\t"-({""})+({""}))[..4];
		int year=(int)season; if (!year) continue; //eg header row
		string pat=year+"-"+replace(idx,"Special ","SP")+" *";
		if (!has_value(exists,fn)) continue; //Doesn't exist - probably already renamed - ignore it.
		write("-- %s\n",fn);
		if (sizeof(glob(pat,exists))) {write("Target already exists: %s --> %s\n",fn,glob(pat,exists)[0]); continue;} //Already renamed - ignore it.
		array(string) tmp=glob(pat,dir); if (!sizeof(tmp)) {write("Not found: %s\n",fn); continue;} //Can't find the target file name??
		string outfn=tmp[0];
		if (notes!="") outfn=notes+" - "+outfn; //This will, deliberately, break the autolinkage and sort the file to the end.
		//write("Processing: %s --> %s\n",fn,outfn); continue; //Uncomment for dry-run mode
		if (!has_suffix(fn,".mkv"))
		{
			Process.create_process(({"avconv","-i","/video/Mythbusters/"+fn,outfn}))->wait();
			if (!file_stat(outfn)) break; //Something went wrong...
			Process.create_process(({"scp",outfn,"huix:/video/Mythbusters/"}))->wait();
			if (!file_stat("/video/Mythbusters/"+outfn)) break; //Transfer failed?
			rm(outfn);
			Process.create_process(({"ssh","huix","rm","/video/Mythbusters/"+sh_quote(fn)}))->wait(); //Yes, double-escape it. SSH is weird sometimes.
		}
		else Process.create_process(({"ssh","huix","mv","/video/Mythbusters/"+sh_quote(fn),"/video/Mythbusters/"+sh_quote(outfn)}))->wait();
	}) {write(line+"\n"); throw(ex);}
}
