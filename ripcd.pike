//Rip a CD to WAV, then rename all the files based on their .inf names

//Utility: Like sprintf, but picks up its data from a mapping.
//In the template string, use %{key} to interpolate data["key"].
//Format string parameters may come between % and {...}.
//Use {{ to mark a literal open brace.
string format(string template,mapping(string:string) data)
{
	string fmt="";
	array(string) args=({ });
	while (sscanf(template,"%s{%s",string before,string after))
	{
		fmt+=before;
		if (after!="" && after[0]=='{') {fmt+="{"; after=after[1..];}
		else if (sscanf(after,"%s}%s",string key,after)) {args+=({data[key]}); fmt+="s";}
		//else throw error?
		template=after;
	}
	return sprintf(fmt+template,@args);
}

int main()
{
	Process.create_process(({"icedax","-D/dev/sr0","-B","-L1"}))->wait();
	for (int i=1;;++i)
	{
		string data=Stdio.read_file(sprintf("audio_%02d.inf",i));
		if (!data) break;
		mapping(string:string) inf=([]);
		foreach (data/"\n",string l)
			if (sscanf(l,"%s=%s",string var,string val) && val && val!="" && var!="" && var[0]!='#')
				inf[String.trim_all_whites(var)]=String.trim_all_whites(val)-"'";
		string newname=format("%02{Tracknumber} %{Tracktitle}.wav",inf);
		write("audio_%02d.wav -> %s\n",i,newname);
		mv(sprintf("audio_%02d.wav",i),newname);
		rm(sprintf("audio_%02d.inf",i));
	}
	rm("audio.cddb");
	rm("audio.cdindex");
}
