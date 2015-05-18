int main(int argc,array(string) argv)
{
	if (argc>1 && argv[1]=="index")
	{
		string url="http://looney.goldenagecartoons.com/WBchecklist.html";
		string data=replace(Protocols.HTTP.get_url_data(url),"\r","");
		sscanf(data,"%{%*s\n19%2d:\n%{____ %s\n%}%}",array years);
		Stdio.File out=Stdio.File("LooneyTunes.txt","wct");
		out->write("Looney Tunes checklist from %s\n\n",url);
		foreach (years,[int year,array(array(string)) titles])
			out->write("%{/19"+year+" - %s.mkv\n%}",titles);
		write("Index rebuilt.\n");
		return 0;
	}
	array(string) files=array_sscanf(Stdio.read_file("LooneyTunes.txt"),"%*s\n\n%{/%s\n%}")[0]*({ });
	//Lift the modified sh_quote() from a similar script
	function sh_quote=((object)"rename.pike")->sh_quote;
	foreach (argv[1..],string fn)
	{
		string base=lower_case(explode_path(fn)[-1]);
		//Clean up the file name as much as possible
		if ((<"avi","mkv","mp4","mpg","mpeg">)[(base/".")[-1]]) base=(base/".")[..<1]*"."; //Trim known file extensions
		sscanf(base,"looney.tunes.%s.19",base);
		sscanf(base,"bugs bunny %s",base);
		sscanf(base,"%*d - %s",base);
		constant strip=":',!. "/1;
		base=replace(base,strip,"");
		string target;
		foreach (files,string f) if (lower_case(replace(array_sscanf(f,"%*d - %s.mkv")[0],strip,""))==base)
		{
			if (target) {werror("Ambiguous: %O could be %O or %O\n",fn,target,f); target=0; break;}
			target=f;
		}
		if (target)
		{
			if (file_stat("/video/LooneyTunes/"+target)) {werror("Target already exists: %O\n",target); continue;}
			//write("Transform %O into %O\n",fn,target); continue;
			if (has_suffix(fn,".mkv"))
			{
				//Simple: directly copy or rename the file.
				if (has_prefix(fn,"/video/")) Process.create_process(({"ssh","huix","sudo","mv",fn,"/video/LooneyTunes/"+sh_quote(target)}))->wait();
				else Process.create_process(({"scp",fn,"netbios@huix:LooneyTunes/"+sh_quote(target)}))->wait();
			}
			else
			{
				//Currently wrong format. First avconv it, then copy it.
				Process.create_process(({"avconv","-i",fn,target}))->wait();
				Process.create_process(({"scp","./"+target,"netbios@huix:LooneyTunes/"}))->wait();
				rm(target);
			}
		}
		else werror("Unable to transform: %O\n",fn);
	}
}
