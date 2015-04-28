//Case-fix a number of path names - good for lifting references from Windows. Note that if it's ambiguous, it's unspecified which fixed pathname will be chosen.
//Produces output, one per line, on stdout. If no args given, reads lines from stdin.
void casefix(string fn)
{
	array(string) path=explode_path(fn);
	for (int i=0;i<sizeof(path);++i)
	{
		string p=combine_path(@path[..i]);
		if (file_stat(p)) continue; //Exists in current case, don't change it.
		array(string) dir=get_dir(i&&combine_path(@path[..i-1]));
		string lookfor=lower_case(path[i]);
		foreach (dir,string f) if (lower_case(f)==lookfor) {path[i]=f; break;}
	}
	write(combine_path(@path)+"\n");
}

int main(int argc,array(string) argv)
{
	if (argc>1) foreach (argv[1..];int i;string fn) casefix(argv[i]);
	else while (string fn=Stdio.stdin.gets()) casefix(fn);
}
