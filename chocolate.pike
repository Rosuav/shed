int main()
{
	string dir="../Downloads/Frozen Dubs";
	foreach (sort(glob("*.ac3",get_dir(dir))),string fn)
		Process.create_process(({"avconv","-i",dir+"/"+fn,"-ss","0:20:53.500","-t","7",fn-".ac3"+".wav"}))->wait();
}
