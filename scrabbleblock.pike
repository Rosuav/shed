/* Attempt to build a huge block, Scrabble-style - or rather, crossword-style with Scrabble tiles.

The constraints are:
1) All words must be longer than the block. If we're making a 3x3 block, all words must be at least
   four letters long.
2) No additional adjacencies outside the block. While this might make the block more awesome, it
   also makes the search much harder.
3) Corollary: Words will alternate which way they stick out. One will have more letters before the
   block, the next will have more letters after the block.
4) There are, therefore, four ways to start the process: sticking out left or right, and sticking
   out top or bottom, for the first pair of words. These four possibilities can be examined on
   completely separate processes. Actually, the whole job is pretty parallelizable, but I won't do
   this in Haskell.
5) All words come from /usr/share/dict/words and will be all-lowercase and have no punctuation.
6) No blank squares will be used in any word. This means that every letter used in every word MUST
   be available. There won't be two Qs coming up. (Of course, a Q inside the block itself will be
   used by exactly two words.)

Letter availabilities: 9 2 2 4 12 2 3 2 9 1 1 4 2 6 8 2 1 6 4 6 4 2 2 1 2 1

Found a 5x5 grid!

      a    
      b   d
      a   a
      n m n
   aardvark
      oaring
discernible
      enlist
   smidgens
       l g 
       o   
       r   
       y   

*/

int size,mode;
array(string) words;
array(int) letters=({9,2,2,4,12,2,3,2,9,1,1,4,2,6,8,2,1,6,4,6,4,2,2,1,2,1});
array(string) grid;
array(array(string)) fullwords;
System.Timer tm=System.Timer();

//Place a word, horizontally or vertically, in position pos
void place_word(int vert,int pos)
{
	if (pos>=size)
	{
		//Grid is solved!
		function write=({write,Stdio.File("scrabbleblock.log","wac")->write}); //Log to file and to stdout
		write("\n\nSOLVED! %f seconds.\n",tm->peek());
		array(string) left=({""})*size,right=({""})*size;
		foreach (fullwords[0];int pos;string word)
		{
			int whichway=(mode&1)^(pos&1);
			if (whichway) left[pos]=word[..<size];
			else right[pos]=word[size..];
		}
		array(string) above=({ }),below=({ });
		foreach (fullwords[1];int pos;string word)
		{
			int whichway=((mode>>1)&1)^(pos&1);
			if (whichway)
			{
				//Place this word above the grid, in above[]
				word=word[..<size];
				if (sizeof(word)>sizeof(above)) above=({" "*size})*(sizeof(word)-sizeof(above))+above;
				int ofs=sizeof(above)-sizeof(word);
				foreach (word;int i;int ch) above[ofs+i][pos]=ch;
			}
			else
			{
				//Place this word below the grid, in below[]
				word=word[size..];
				if (sizeof(word)>sizeof(below)) below+=({" "*size})*(sizeof(word)-sizeof(below));
				foreach (word;int i;int ch) below[i][pos]=ch;
			}
		}
		int indent=max(@sizeof(left[*]));
		write("%{"+" "*indent+"%s\n%}",above);
		for (int i=0;i<size;++i)
			write("%"+indent+"s%s%s\n",left[i],grid[i],right[i]);
		write("%{"+" "*indent+"%s\n%}",below);
		words-=fullwords[0]+fullwords[1]; //Remove all words used, to give more interesting multiple results
		throw("Restart");
	}
	//write("Attempting to place a %s word at pos %d\n",({"horizontal","vertical"})[vert],pos);
	//Do we have letters before the word (whichway==1) or after (0)?
	//This is toggled by mode (if mode is 0, we start with 0 and 0; mode of 2 means we start
	//with 0 horizontal or 1 vertical), and alternates according to pos.
	int whichway=((mode>>vert)&1)^(pos&1);
	string pat = vert ? (string)grid[*][pos] : grid[pos]; //Take either a row or a column
	foreach (Regexp.SimpleRegexp(whichway?pat+"$":"^"+pat)->match(words),string word)
	{
		//Okay. Every word we have here complies with several of our constraints; we just
		//need to check that the letters are all available (not counting those in the pat
		//so we add them back on first), and recurse.
		array(int) prevltrs=letters+({ });
		foreach (pat;;int ch) if (ch!='.') letters[ch-'a']++;
		int ok=1;
		foreach (word;;int ch) if (--letters[ch-'a']<0) ok=0;
		if (!ok) {letters=prevltrs; continue;}
		//Awesome! Seems to work. We've changed letters[] so now just add it to the grid!
		string gridletters = whichway ? word[<size-1..] : word[..size-1];
		if (vert) foreach (gridletters;int i;int ch) grid[i][pos]=ch;
		else grid[pos]=gridletters;
		fullwords[vert][pos]=word;
		//Recurse! Alternate between vertical and horizontal placement, and advance to the
		//next position if we just did a vertical one.
		place_word(!vert,pos+vert);
		//Nope, didn't work. Reinstate letters.
		letters=prevltrs;
	}
	//Since this didn't terminate, this search failed. Remove what we've placed.
	if (vert) foreach (pat;int i;int ch) grid[i][pos]=ch;
	else grid[pos]=pat;
}

int main(int argc,array(int) argv)
{
	if (argc<3) exit(0,"Usage: pike %s N M\nN is size of block, eg 3 for 3x3. M is 0, 1, 2, 3 for which mode to check.\n",argv[0]);
	size=(int)argv[1]; mode=(int)argv[2];
	if (size<2 || mode<0 || mode>3) exit(0,"Usage: pike %s N M\nN is size of block, eg 3 for 3x3. M is 0, 1, 2, 3 for which mode to check.\n",argv[0]);
	//SimpleRegexp doesn't handle ^[a-z]{n,}$ so we do it as n copies of [a-z] with the last one modified by a +.
	words=Regexp.SimpleRegexp("^"+"[a-z]"*(size+2)+"+$")->match(Stdio.read_file("/usr/share/dict/words")/"\n");
	write("%d words.\n",sizeof(words));
	grid=({"."*size})*size;
	fullwords=({({""})*size,({""})*size});
	while (1)
	{
		mixed ex=catch {place_word(0,0);};
		if (ex!="Restart") throw(ex);
	}
}
