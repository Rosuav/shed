int main(int argc,array(string) argv)
{
	if (argc<3) exit(0,"Usage: %s path_to_dvd output_file_name\n",argv[0]);
	array(string) files=sort(get_dir(argv[1]+"/VIDEO_TS"));
	for (int i=1;;++i)
	{
		array(string) f=glob(sprintf("VTS_%02d_*.VOB",i),files);
		if (!sizeof(f)) break; //Come to the end of the titles
		f-=glob("*_0.VOB",f); //Ignore VTS_nn_0.VOB
		write("cat%{ "+argv[1]+"/VIDEO_TS/%s%}|avconv -i - %s\n",f,Process.sh_quote(sprintf(argv[2],i))); continue;
		Stdio.File pipe=Stdio.File();
		object proc=Process.create_process(({"avconv","-i","-",sprintf(argv[2],i)}),(["stdin":pipe->pipe(Stdio.PROP_IPC|Stdio.PROP_REVERSE)]));
		foreach (f,string fn)
		{
			Stdio.File in=Stdio.File(argv[1]+"/"+fn);
			while (string data=in->read(1048576)) if (pipe->write(data)<=0) break;
		}
		pipe->close();
		proc->wait();
		werror("Finished transcoding %02d.\n",i);
	}
}
