//Convert a PMMail/2 mail store into maildir format
string subs="";

void process(string source,string target)
{
	foreach (get_dir(source),string fn) if (has_suffix(lower_case(fn),".fld"))
	{
		//Note that the source is case insensitive, so we need to figure out the file name.
		string folderini;
		string src=source+"/"+fn;
		array contents=get_dir(src);
		foreach (contents,string f) if (lower_case(f)=="folder.ini") {folderini=src+"/"+f; break;}
		if (!folderini) continue; //Can't be a proper PMMail folder if it doesn't have an ini.
		sscanf(Stdio.read_file(folderini),"%s\xde",string folder);
		string fld=target+"."+folder; //Yes, dot not slash.
		foreach (({"","/cur","/new","/tmp"}),string dir) mkdir(fld+dir);
		write("Copying %s to %s...\n",src,fld);
		foreach (contents,string f) if (has_suffix(lower_case(f),".msg")) Stdio.cp(src+"/"+f,fld+"/"+lower_case(f));
		subs+="INBOX"+fld+"\n";
		process(src,fld); //Recurse into any subfolders
	}
}

int main(int argc,array(string) argv)
{
	if (argc<2) exit(0,"Usage: %s targetdir\n\nWill process targetdir and create a maildir tree in the current directory.\n",argv[0]);
	process(argv[1],"");
	Stdio.append_file("courierimapsubscribed.new",subs);
	write("Copying complete. To automatically subscribe, append this to courierimapsubscribed:\n%s\n\nThis has been written to courierimapsubscribed.new for convenience.\n",subs);
}
