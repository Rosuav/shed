constant basedir="../Downloads/Let It Go (The Complete Set) (From Frozen) YG";
int main(int argc,array(string) argv)
{
	array(string) dir=({ });
	for (int i=1;i<=2;++i)
	{
		string path=basedir+"/CD"+i+"/";
		dir+=path+utf8_to_string(sort(get_dir(path))[*])[*];
	}
	nextarg: foreach (argv[1..],string fn)
	{
		string findme=lower_case(utf8_to_string(fn))-".srt";
		foreach (dir,string f) if (has_value(lower_case(f),findme))
		{
			sscanf((f/"/")[-1],"%*s(%s Version).%s",string lang,string mp3);
			if (!lang || mp3!="mp3") lang=fn-".srt";
			write("Creating: %O\n",lang);
			Process.create_process(({"avconv",
				"-i","/video/Clips/Frozen - Let It Go.mkv",
				"-i",string_to_utf8(f),
				"-i",fn,
				"-map","0:v","-map","1:a:0","-map","2:s",
				"-c","copy",lang+".mkv"
			}))->wait();
			continue nextarg;
		}
		write("Not found: %s\n",fn);
	}
}

