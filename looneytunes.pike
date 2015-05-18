string canonicalize(string fn)
{
	fn=lower_case(fn);
	if ((<"avi","mkv","mp4","mpg","mpeg">)[(fn/".")[-1]]) fn=(fn/".")[..<1]*"."; //Trim known file extensions
	sscanf(fn,"looney.tunes.%s.19",fn);
	fn=replace(fn," - "," ");
	sscanf(fn,"bugs bunny %s",fn);
	sscanf(fn,"%*d%s",fn);
	sscanf(String.trim_all_whites(fn),"the %s",fn);
	sscanf(String.trim_all_whites(fn),"a %s",fn);
	fn=replace(fn,":',?!-. "/1,"");
	return fn;
}

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
	mapping(string:string) decanonicalize=([]);
	foreach (array_sscanf(Stdio.read_file("LooneyTunes.txt"),"%*s\n\n%{/%s\n%}")[0],[string fn])
	{
		string canon=canonicalize(fn);
		//if (decanonicalize[canon]) exit(1,"Canonicalization collision on %O: %O and %O\n",canon,decanonicalize[canon],fn); //Raise immediate error on collision, or...
		if (decanonicalize[canon]) fn="! Collision !"; //... just record the problem (throw error only if we try to use this)
		decanonicalize[canon]=fn;
	}
	//Lift the modified sh_quote() from a similar script
	function sh_quote=((object)"rename.pike")->sh_quote;
	int verbose=0,nerfed=0;
	foreach (argv[1..],string fn)
	{
		if (fn=="-v") {verbose=1; continue;}
		if (fn=="-n") {nerfed=1; continue;}
		if (string target=decanonicalize[canonicalize(explode_path(fn)[-1])])
		{
			if (target=="! Collision !") exit(1,"Ambiguous canonicalization on %O\n",fn);
			if (file_stat("/video/LooneyTunes/"+target)) {if (verbose) write("Target already exists: %O\n",target); continue;}
			if (nerfed) {write("Transform %O into %O\n",fn,target); continue;}
			if (has_suffix(fn,".mkv"))
			{
				//Simple: directly copy or rename the file.
				if (has_prefix(fn,"/video/")) Process.create_process(({"ssh","huix","sudo","mv",sh_quote(fn),"/video/LooneyTunes/"+sh_quote(target)}))->wait();
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
