int srt2ms(string srt)
{
	sscanf(srt,"%d:%d:%d,%d",int hr,int min,int sec,int ms);
	return hr*3600000+min*60000+sec*1000+ms;
}

string srttime(int tm)
{
	return sprintf("%02d:%02d:%02d,%03d",tm/3600000,(tm/60000)%60,(tm/1000)%60,tm%1000);
}

int main(int argc,array(string) argv)
{
	if (argc<2) exit(0,"USAGE: pike %s filename.srt\n",argv[0]);
	array(array(string)) input=(String.trim_all_whites(Stdio.read_file(argv[1]))/"\n\n")[*]/"\n";
	array(float) data=allocate(sizeof(input));
	array(float) diff=allocate(sizeof(input));
	int top=srt2ms(input[-1][input[-1][0]==(string)(int)input[-1][0]]);
	float avg=(float)top/sizeof(input);
	write("Average time to subtitle line: %f seconds\n",avg/1000);
	array(string) srtpos=allocate(sizeof(input));
	float peak=-999.0,trough=999.0; string peakpos,troughpos;
	object out = argc>2 && Stdio.File(argv[2],"wct");
	foreach (input;int i;array(string) lines)
	{
		if (lines[0]==(string)(int)lines[0]) input[i]=lines=lines[1..]; //Trim off any index markers
		float expected=avg*(i+1);
		float actual=(float)srt2ms(lines[0]);
		data[i]=(expected-actual)/avg;
		diff[i]=data[i]-data[i-1];
		srtpos[i]=(lines[0]/" --> ")[0]; if (sizeof(lines)>1) srtpos[i]+=" "+lines[1];
		if (data[i]>peak) {peak=data[i]; peakpos=srtpos[i];}
		if (data[i]<trough) {trough=data[i]; troughpos=srtpos[i];}
		if (out) out->write("%s\n%f - %s, expect %s\n%{%s\n%}\n",lines[0],data[i],(lines[0]/" --> ")[0],srttime((int)expected),lines[1..]);
	}
	write("Peak: %f %s\nTrough: %f %s\n",peak,peakpos,trough,troughpos);
	object img=Graphics.Graph.line((["data":({data,diff}),"xsize":1024,"ysize":768]));
	GTK2.setup_gtk();
	GTK2.Window(0)->set_title("Plot")->add(GTK2.Image(GTK2.GdkImage(0,img)))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	return -1;
}
