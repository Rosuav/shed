int srt2ms(string srt)
{
	sscanf(srt,"%d:%d:%d,%d",int hr,int min,int sec,int ms);
	return hr*3600000+min*60000+sec*1000+ms;
}

int main(int argc,array(string) argv)
{
	if (argc<5) exit(1,"USAGE: %s inputfile starttime endtime [other options...] outputfile\n",argv[0]);
	int start=srt2ms(argv[2]),end=srt2ms(argv[3]);
	end-=start; //Use relative time rather than absolute
	string st=sprintf("%d.%03d",start/1000,start%1000);
	string en=sprintf("%d.%03d",end/1000,end%1000);
	Process.exec("avconv","-i",argv[1],"-ss",st,"-t",en,@argv[4..]);
	exit(1,"Unable to exec avconv\n");
}
