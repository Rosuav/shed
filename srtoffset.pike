//Convert SRT time format to integer milliseconds
int srt2ms(string srt)
{
	sscanf(srt,"%d:%d:%d,%d",int hr,int min,int sec,int ms);
	return hr*3600000+min*60000+sec*1000+ms;
}

//Convert a millisecond time position into .srt format: HH:MM:SS,mmm (comma between seconds and milliseconds)
string srttime(int tm)
{
	return sprintf("%02d:%02d:%02d,%03d",tm/3600000,(tm/60000)%60,(tm/1000)%60,tm%1000);
}

int main(int argc,array(string) argv)
{
	if (argc<4) exit(0,"USAGE: pike %s input.srt delay output.srt\n");
	[string infn,string delay,string outfn]=argv[1..3];
	int offset=srt2ms(replace(delay-"-",".",",")); //Allow a dot instead of a comma
	if (delay[0] == '-') offset = -offset;
	array(array(string)) input=(String.trim_all_whites(utf8_to_string(Stdio.read_file(infn)))/"\n\n")[*]/"\n";
	foreach (input;int i;array(string) lines)
	{
		if (lines[0]==(string)(int)lines[0]) input[i]=lines=lines[1..]; //Trim off any index markers
		array(int) ms = srt2ms((lines[0]/" --> ")[*]);
		if (delay == "25/24") ms = (ms[*] * 25)[*] / 24;
		else if (delay == "24/25") ms = (ms[*] * 24)[*] / 25;
		else ms = ms[*] + offset;
		lines[0] = srttime(ms[*]) * " --> ";
	}
	Stdio.write_file(outfn,string_to_utf8(input[*]*"\n"*"\n\n"+"\n"));
}
