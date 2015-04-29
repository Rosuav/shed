//Borrows somewhat from Process.run()
void multirun(array(string) cmd,array(string) inputs,mapping modifiers)
{
	Stdio.File mystdin = Stdio.File();
	Process.create_process(cmd, modifiers + (["stdin":mystdin->pipe(Stdio.PROP_IPC|Stdio.PROP_REVERSE)]));
	Shuffler.Shuffler sfr = Shuffler.Shuffler();
	Shuffler.Shuffle sf = sfr->shuffle(mystdin);
	sf->add_source(Stdio.File(inputs[*])[*]);
	sf->set_done_callback (lambda () {
		catch { mystdin->close(); };
		mystdin = 0;
	});
	sf->start();
}

int nextidx=0;
string destdir;
array(string) input;
array(string) audio=({"0"});

void spawnnext()
{
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
	int wid=Stdio.stdin->tcgetattr()->columns-1;
	write("-"*wid+"\nStarting part %d\n"+"-"*wid+"\n",nextidx);
	string dest=sprintf("%s%d.mkv",destdir,nextidx++);
	rm(dest);
	multirun(({"avconv","-i","-","-c","copy","-map","0:v","-map","0:a:"+audiotrack,dest}),inputs[*]+".m2ts",(["callback":spawnnext]));
}

int main(int argc,array(string) argv)
{
	if (argc<3) exit(1,"USAGE: pike %s [-a0/0/0] 00000 00000/00000/00000/00000 ~/destination/prefix\nCAUTION: Can use a lot of disk space!\n",argv[0]);
	destdir=argv[-1];
	input=argv[1..<1];
	if (has_prefix(input[0],"-a")) {audio=input[0][2..]/"/"; input=input[1..];}
	spawnnext();
	return -1;
}
