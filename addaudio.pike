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
	array(string) cmd=({"ffmpeg"});
	array(string) map=({"-c:v","copy","-map","0:v"});
	for (int i=1;i<argc-1;++i)
	{
		cmd+=({"-i",argv[i]});
		string idx=(string)(i-1);
		string title=(explode_path(argv[i])[-1]/".")[0]; //Tidy up the path into a base name to be used if there's no useful metadata
		map+=({"-map",idx+":a:0","-metadata:s:a:"+idx,"title="+title,"-map_metadata:s:a:"+idx,idx});
	}
	cmd+=map+({"-metadata:s:a:0","title=Original",argv[-1]});
	//write("%{%s %}\n",sh_quote(cmd[*]));
	Process.exec(@cmd);
}
