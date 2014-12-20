//Like Process.sh_quote() but also replaces ( and ) which have meaning to several shells
string sh_quote(string s)
{
  return replace(s,
	({"\\", "'", "\"", " ","(",")"}),
	({"\\\\", "\\'", "\\\"","\\ ","\\(","\\)"}));
}

int main(int argc,array(string) argv)
{
	if (argc<4) exit(0,"USAGE: pike %s videofile audiofile[ audiofile...] outputfile\nAttaches all the audio files as separately playable tracks.\n");
	array(string) cmd=({"avconv"});
	array(string) map=({"-c","copy","-map","0:v","-metadata:s:a:0","title=Original"});
	for (int i=1;i<argc-1;++i)
	{
		cmd+=({"-i",argv[i]});
		string idx=(string)(i-1);
		map+=({"-map",idx+":a:0","-map_metadata:s:a:"+idx,idx});
	}
	cmd+=map+({argv[-1]});
	//write("%{%s %}\n",sh_quote(cmd[*]));
	Process.exec(@cmd);
}
