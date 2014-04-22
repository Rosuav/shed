/*
Simple, but handy: rename BiCapitalizedFileNames to have spaces in them.
Pass it a prefix and a file name; will put the prefix, then a dash, then
the file name with spaces:

$ pike ren Anastasia OnceUponADecember.mkv

will rename "OnceUponADecember.mkv" to "Anastasia - Once Upon A December.mkv".
Doesn't work in bulk, currently, though that wouldn't be hard to do.
*/
int main(int argc,array(string) argv)
{
	mv(argv[2],argv[1]+" -"+Regexp.replace("[A-Z]",argv[2],lambda(string x) {return " "+x;}));
}
