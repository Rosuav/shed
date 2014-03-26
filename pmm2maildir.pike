/* Convert a PMMail/2 mail store into maildir format

Usage: Switch to a target directory (might be your mail store, or a temporary directory)
and run this script, passing it a source directory name, which will normally be the .ACT
directory. All mail will be copied, not referenced, so the old directory can be disposed
of once the transfer is complete.

The directories will be created ready to go, but will not automatically be subscribed to
in IMAP. A new file, courierimapsubscribed.new, will be created (or appended to if it is
already present); it's lines of plain text, and can be appended to courierimapsubscribed
to automatically subscribe, or the user can manually subscribe in the UI.

Key files (eg folder.ini) will be searched for case insensitively, even on a file system
that's case sensitive. This is inefficient but reliable.
*/
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
		string fld=target+"."+replace(folder,({".","/"}),"_"); //Yes, dot not slash. Any actual dots or slashes in the folder name can become underscores.
		foreach (({"","/cur","/new","/tmp"}),string dir) mkdir(fld+dir);
		write("Copying %s...\n",fld);
		foreach (contents,string f) if (has_suffix(lower_case(f),".msg")) Stdio.cp(src+"/"+f,fld+"/new/"+lower_case(f));
		subs+="INBOX"+fld+"\n";
		process(src,fld); //Recurse into any subfolders
	}
}

int main(int argc,array(string) argv)
{
	if (argc<2) exit(0,"Usage: %s sourcedir\n\nWill process sourcedir and create a maildir tree in the current directory.\n",argv[0]);
	process(argv[1],"");
	Stdio.append_file("courierimapsubscribed.new",subs);
	write("Copying complete. To automatically subscribe, append the contents\nof courierimapsubscribed.new to courierimapsubscribed in the mail directory.\n",subs);
}
