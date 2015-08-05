//Find files that exist here and in the parent directory
string md5sum(string fn) {return String.string2hex(Crypto.MD5.hash(Stdio.File(fn)));}

int main()
{
	foreach (sort(get_dir()),string fn)
	{
		object stat=file_stat(fn);
		if (!stat) {werror("Unable to stat: %O\n",fn); continue;}
		if (stat->isdir) {write("Ignoring directory: %O\n",fn); continue;}
		object parent=file_stat("../"+fn);
		if (!parent) continue; //File does not exist in parent.
		if (parent->size && !stat->size) {write("Replacing empty file with non-empty from parent: %O\n",fn); mv("../"+fn,fn); continue;}
		if (!parent->size && stat->size) {write("Discarding empty file from parent: %O\n",fn); rm("../"+fn); continue;}
		if (parent->size!=stat->size) {write("Files differ in size: %O\n",fn); continue;} //Two non-empty sizes? Let the human figure it out.
		write("Hashing %s... ",fn);
		string cur=md5sum(fn);
		write("\b\b\b\b and parent... ");
		string par=md5sum("../"+fn);
		write("done\n");
		if (cur!=par) write("Different checksums:\n%s ../%s\n%s    %[1]s\n",par,fn,cur); //Likewise, two different files - let the human deal with it.
		else {write("Discarding identical file from parent: %O\n",fn); rm("../"+fn);}
	}
}
