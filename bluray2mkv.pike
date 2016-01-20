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
string|array(string) target;
array(string) input,originput;
array(string) audio=({"0"});
string mountpoint;

array automount=({
	({"lazers-frozen3d-bd.iso",({"English","French","Latin American Spanish"}),"-a0/2/3 00877 00895/00896/00897 00898 00899/00900/00901 00902 00903/00904/00905 00906 00907/00908/00909 00910 00911/00912/00911 00913"/" "}),
	//I have four audio tracks but only three pictures. Ah well... guess the Turkish can go with the English images.
	({"ret-frozen-bd.iso",({"English 2","Italian","German","Turkish"}),"-a0/1/2/3 00879 00880/00889/00894 00881 00882/00890/00895 00883 00884/00891/00896 00885 00886/00892/00943 00887"/" "}),
	//Inside Out has a lot more text on the screen. Same problem with lack of Dutch and Flemish text, though.
	({"INSIDE_OUT_3D.iso",({"IO-English","IO-French","IO-Italian","IO-Dutch","IO-Flemish"}),"-a0/5/6/4/7 00300 00301/00347/00348 00302 00303/00349/00350 00304 00305/00351/00352 00306 00307/00353/00354 00308 00309 00310 00311/00357/00358 00312 00313/00359/00360 00314 00315/00361/00362 00316 00317/00363/00364 00318 00319/00365/00366 00320 00321/00367/00368 00322 00323/00369/00370 00324 00325/00371/00372 00326 00327/00373/00374 00328 00329/00375/00376 00330 00332 00333/00379/00380 00334 00335/00381/00382 00336 00337/00383/00384 00338 00339/00385/00386 00340 00341/00387/00388 00342 00343/00389/00390 00344 00345/00391/00392"/" "}),
	({"gerudo-inside.out.bd.iso",({"IO-English-2","IO-Commentary"}),"-a0/7 00469 00476 00470"/" "}),
});

void spawnnext(object|void proc)
{
	if (proc) {closeme->close(); proc->wait(); destruct(proc);} //Close all files and reap the child
	if (target==({ }))
	{
		cd(System.get_home());
		Process.create_process(({"sudo","umount",mountpoint}))->wait();
		rm(mountpoint);
		exit(0);
	}
	if (originput) input=originput+({ });
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
	string dest;
	if (arrayp(target)) [dest,target]=Array.shift(target);
	else dest=sprintf("%s%d.mkv",target,nextidx);
	++nextidx;
	rm(dest);
	multirun(({"avconv","-i","-","-c:s","copy","-map","0:v","-map","0:a:"+audiotrack,"-map","0:s",dest}),inputs[*]+".m2ts",(["callback":spawnnext]));
}

int main(int argc,array(string) argv)
{
	if (argc==2)
	{
		foreach (automount,[string fn,array(string) lang,array(string) parts]) if (fn==argv[1] || has_value(lang,argv[1]))
		{
			nextidx=search(lang,argv[1]);
			originput=parts;
			if (nextidx>-1) target=({getcwd()+"/"+argv[1]+".mkv"});
			else {nextidx=0; target=sprintf(getcwd()+"/%s.mkv",lang[*]);}
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
