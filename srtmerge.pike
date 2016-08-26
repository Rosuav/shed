//Convert SRT time format to integer milliseconds
int srt2ms(string srt)
{
	sscanf(srt,"%d:%d:%d,%d",int hr,int min,int sec,int ms);
	return hr*3600000+min*60000+sec*1000+ms;
}

//Trim junk off a line - markers of various sorts that we don't care about
//Note that this will be called on the synchronization line, and MUST NOT damage it
string trim(string line)
{
	line = replace(line, ({"<i>", "</i>"}), "");
	if (has_prefix(line, "#")) line = line[1..];
	if (has_prefix(line, "-")) line = line[1..];
	return String.trim_all_whites(line);
}

int main(int argc,array(string) argv)
{
	mapping args = Arg.parse(argv);
	[string outfn, array(string) files] = Array.pop(args[Arg.REST]);
	if (sizeof(files)<2) exit(0, #"USAGE: pike %s input1.srt input2.srt [input3.srt...] output.srt
Attempts to 'zip' the inputs into the output. Options:
	//--oneline - fold each block to a single line
	--translit=language - add a transliteration back to Latin
	--trim - trim off leading/trailing '#', '-', '<i>', etc
");
	write("Combining to %s:\n%{\t%s\n%}",outfn,files);
	function translit;
	if (args->translit)
	{
		translit=((object)"translit.pike")[String.capitalize(args->translit) + "_to_Latin"];
		if (!translit) write("WARNING: %O transliteration not found, ignoring\n", args->translit);
	}
	//The first file is the one that creates the final output. All other
	//files are simply merged into the nearest slot based on start time.
	//Also: That is one serious line of code. I'm not sure this is *good* code, but it's impressive how much automap will do for you.
	[array(array(string)) output,array(array(array(string))) inputs]=Array.shift((String.trim_all_whites(utf8_to_string(Stdio.read_file(files[*])[*])[*])[*]/"\n\n")[*][*]/"\n");
	//Trim off any index markers. We can re-add them later if they're wanted.
	foreach (output; int i; array(string) lines)
	{
		if (lines[0] == (string)(int)lines[0]) output[i] = lines = lines[1..];
		if (args->trim) foreach (lines; int j; string line) lines[j] = trim(line);
	}
	foreach (inputs,array(array(string)) input)
	{
		int pos=0; //We'll never put anything earlier in the file than a previous insertion. (Also speeds up the search; in the common cases, we'll check just two or three entries.)
		foreach (input,array(string) lines)
		{
			if (lines[0]==(string)(int)lines[0]) lines=lines[1..]; //As above, trim off index markers; it's more important here as they're likely to be flat-out wrong after the merge.
			int inputtime=srt2ms(lines[0]);
			while (pos<sizeof(output)-1)
			{
				//See if pos should be incremented.
				//The current rule is: If the next output starts before, or no more than one second after, the current input, advance.
				//This allows a little slop in the alignment, but defaults to connecting pieces together.
				//Note that once we reach the end of the template file, everything will just be appended to the last entry.
				int nextouttime=srt2ms(output[pos+1][0]);
				if (nextouttime-1000<inputtime) ++pos; else break;
			}
			if (args->trim) foreach (lines; int j; string line) lines[j] = trim(line);
			//Optional: Add a transliteration on the way through.
			if (translit) output[pos]+=({translit(lines[1])});
			output[pos]+=lines[1..];
		}
	}
	Stdio.write_file(outfn,string_to_utf8(output[*]*"\n"*"\n\n"+"\n"));
}
