//Combine a series of .srt files into one, interleaving as required.
//Unlike srtmerge, this has no concept of "primary", and simply takes
//from all its inputs based on the lowest (string-based) start time.
int main(int argc,array(string) argv)
{
	array(string) files=argv[1..<1];
	string outfn=argv[-1];
	if (sizeof(files)<2) exit(0,"USAGE: pike %s input1.srt input2.srt [input3.srt...] output.srt\nAttempts to 'zip' the inputs into the output.\n");
	write("Combining to %s:\n%{\t%s\n%}",outfn,files);
	array(array(string)) inputs=String.trim_all_whites(utf8_to_string(Stdio.read_file(files[*])[*])[*])[*]/"\n\n";
	//Trim off all index markers. We can re-add them later if they're wanted.
	foreach (inputs,array(string) inp) foreach (inp;int i;string para) if (sscanf(para,"%*d\n%s",string newpara)==2) inp[i]=newpara;
	Stdio.File out=Stdio.File(outfn,"wct");
	int idx=0;
	while (1)
	{
		int first=-1; string best="9";
		foreach (inputs;int i;array(string) inp) if (sizeof(inp) && inp[0]<best) {first=i; best=inp[0];}
		if (first==-1) break; //All arrays are empty - we're done!
		inputs[first]=inputs[first][1..];
		out->write("%d\n%s\n\n",++idx,string_to_utf8(best));
	}
}
