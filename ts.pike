int lastout='\n',lasterr='\n';
void tsout(string txt)
{
	if (lastout=='\n') txt=ctime(time())[..<1]+txt; //TODO: Also handle \r
	if (txt[-1]=='\n') {txt=txt[..<1]; lastout='\n';} else lastout=0;
	write(replace(txt,"\n","\n"+ctime(time())[..<1]));
	if (lastout) write("\n");
}

void tserr(string txt) //TODO: Dedup
{
	if (lasterr=='\n') txt=ctime(time())[..<1]+txt;
	if (txt[-1]=='\n') {txt=txt[..<1]; lasterr='\n';} else lasterr=0;
	werror(replace(txt,"\n","\n"+ctime(time())[..<1]));
	if (lasterr) werror("\n");
}

int main(int argc,array(string) argv)
{
	return Process.run(argv[1..],(["stdout":tsout,"stderr":tserr]))->exitcode;
}
