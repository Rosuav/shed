string canonicalize(string fn)
{
	fn=lower_case(fn);
	if ((<"avi","mkv","mp4","mpg","mpeg","flv">)[(fn/".")[-1]]) fn=(fn/".")[..<1]*"."; //Trim known file extensions
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
		//NOTE: This destroys local changes (such as those done by the tag importer below).
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
	if (argc>2 && argv[1]=="tags")
	{
		//Import tags from the given file. Modifies the local LooneyTunes.txt to include them.
		mapping(string:array) tags=([]);
		foreach (utf8_to_string(Stdio.read_file(argv[2]))/"\n",string line)
		{
			line=line-"\ufeff"-"\r"; //Hack: Remove CRs, and any stupid BOM that managed to get through (Notepad, you suck)
			if (line=="") continue; //Ignore blanks
			//Lines should be: 1945	Hare Tonic	Bugs	7	|4=Rabbititis.mp4|9=LOONEY%20TUNES%20COLLECTION%5CLooney%20Tunes%20Golden%20Collection%20Volume%203%20-%20Disk%201%5C03%20-%20Hare%20Tonic.avi|
			array info=array_sscanf(line,"%s\t%s\t%s\t%d\t%*[|]%{%d=%s|%}"); //We need it as an array anyway. These are: year, title, keywords, quality, [(qual, path)...]
			foreach (info[-1],array a) a[1]=Protocols.HTTP.uri_decode(a[1]); //The file names are URI-encoded
			string canon=canonicalize(info[1]);
			if (tags[canon]) exit(1,"Collision on canonical form %s!\n",canon); //Shouldn't happen - these were manually entered and should be unique.
			tags[canon]=info;
		}
		write("Loaded %d entries.\n",sizeof(tags));
		sscanf(Stdio.read_file("LooneyTunes.txt"),"%s\n\n%{/%s\n%}",string header,array content);
		//NOTE: Don't actually overwrite the file yet; even though storing the data is less
		//efficient, we need to make sure we don't blow away the file if there's an error.
		string outdata=header+"\n\n";
		foreach (content,[string fn])
		{
			outdata+=sprintf("/%s\n",fn);
			string canon=canonicalize(fn);
			if (!tags[canon]) continue;
			[string year,string title,string keywords,int quality,array(array(int|string)) avail] = tags[canon];
			if (!has_prefix(fn,year)) exit(1,"Error: File name %O does not match year %O\n",fn,year);
			if (canonicalize(title)!=canon) exit(1,"Error: File name %O does not match title %O\n",fn,title);
			if (file_stat("/video/LooneyTunes/"+fn)) avail=({ }); //If we have the file, we don't care about its old availabilities on Windows.
			outdata+=sprintf("Score: %d/10\nKeywords:%{ $%s%}\n%{File name [%d]: %s\n%}\n",quality,keywords/", ",avail);
		}
		Stdio.write_file("LooneyTunes.txt",outdata);
		return 0;
	}
	mapping(string:string) decanonicalize=([]);
	foreach (Stdio.read_file("LooneyTunes.txt")/"\n",string fn)
	{
		if (!sscanf(fn,"/%s",fn)) continue;
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
