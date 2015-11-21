//Borrows ideas from Process.run()
array(Stdio.File) closeme=({ });
void multirun(array(string) cmd,array(string) inputs,mapping modifiers)
{
	Stdio.File mystdin = Stdio.File();
	Process.create_process(cmd, modifiers + (["stdin": mystdin->pipe(Stdio.PROP_IPC|Stdio.PROP_REVERSE)]));
	Shuffler.Shuffle sf = Shuffler.Shuffler()->shuffle(mystdin);
	closeme=Stdio.File(inputs[*]);
	sf->add_source(closeme[*]);
	sf->set_done_callback(lambda () {catch {mystdin->close();};});
	sf->start();
}

int nextidx=0;
string target;
array(string) input;
array(string) audio=({"0"});
string mountpoint;

array automount=({
	({"lazers-frozen3d-bd.iso",({"English","French","Latin American Spanish"}),"-a0/2/3 00877 00895/00896/00897 00898 00899/00900/00901 00902 00903/00904/00905 00906 00907/00908/00909 00910 00911/00912/00911 00913"/" "}),
	//I have four audio tracks but only three pictures. Ah well... guess the Turkish can go with the English images.
	({"ret-frozen-bd.iso",({"English 2","Italian","German","Turkish"}),"-a0/1/2/3 00879 00880/00889/00894 00881 00882/00890/00895 00883 00884/00891/00896 00885 00886/00892/00943 00887"/" "}),
	({"INSIDE_OUT_3D.iso",({"IO-English","IO-French","IO-Italian"}),"-a0/5/6/7 -s0/1/2/3 00301/00347/00348"/" "}),
});

void spawnnext(object|void proc)
{
	if (proc) {closeme->close(); proc->wait(); destruct(proc);} //Close all files and reap the child
	if (!target)
	{
		cd(System.get_home());
		Process.create_process(({"sudo","umount",mountpoint}))->wait();
		rm(mountpoint);
		exit(0);
	}
	if (has_prefix(input[0],"-a")) {audio=input[0][2..]/"/"; input=input[1..];}
	array(string) inputs=allocate(sizeof(input));
	int ok=0;
	foreach (input;int i;string arg)
	{
		array(string) split=arg/"/";
		//If there are enough parts, take this one. Otherwise, take the first (most likely it's a one-part entry, so "take the only one").
		//Once we run out of entries that have lots of parts, we're done processing.
		if (sizeof(split)>nextidx) {ok=1; inputs[i]=split[nextidx];}
		else inputs[i]=split[0];
	}
	string audiotrack=audio[0];
	if (sizeof(audio)>nextidx) {ok=1; audiotrack=audio[nextidx];}
	if (!ok) exit(0);
	int wid=Stdio.stdin->tcgetattr()->columns || 80;
	write("-"*(wid-1)+"\nStarting part %d\n"+"-"*(wid-1)+"\n",nextidx);
	string dest=sprintf("%s%d.mkv",target,nextidx++);
	if (has_suffix(target,".mkv")) {dest=target; target=0;} //Hack: Doing just one output. Signal that this is the last.
	rm(dest);
	multirun(({"avconv","-i","-","-c","copy","-map","0:v","-map","0:a:"+audiotrack,"-map","0:s",dest}),inputs[*]+".m2ts",(["callback":spawnnext]));
}

int main(int argc,array(string) argv)
{
	if (argc==2)
	{
		foreach (automount,[string fn,array(string) lang,array(string) parts]) if (has_value(lang,argv[1]))
		{
			nextidx=search(lang,argv[1]);
			input=parts;
			target=getcwd()+"/"+argv[1]+".mkv";
			mountpoint="/tmp/"+fn;
			mkdir(mountpoint);
			Process.create_process(({"sudo","mount",System.get_home()+"/"+fn,mountpoint}))->wait();
			cd(mountpoint+"/BDMV/STREAM");
			spawnnext();
			return -1;
		}
	}
	if (argc<3) exit(1,"USAGE: pike %s [-a0/0/0] 00000 00000/00000/00000/00000 ~/destination/prefix\nCAUTION: Can use a lot of disk space!\n",argv[0]);
	target=argv[-1];
	input=argv[1..<1];
	spawnnext();
	return -1;
}
