//Find the most similar pair of a set of files
//All arguments that can be statted are files; all others are passed on to diff(1).
//All pairs of files are tested exhaustively (though only 'forwards' - the same files
//in the other order won't be tested), and whichever pair results in the least bytes
//of diff output is printed to stdout.
int main(int argc,array(string) argv)
{
	array(string) files=filter(argv[1..],file_stat);
	array(string) args=argv[1..]-files;
	string bestoutput;
	foreach (files;int i;string fn1) foreach (files[i+1..],string fn2)
	{
		string output=Process.run(({"diff"})+args+({fn1,fn2}))->stdout;
		if (!bestoutput || sizeof(bestoutput)>sizeof(output)) bestoutput=output;
	}
	write(bestoutput);
}
