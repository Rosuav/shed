int main(int argc, array(string) argv)
{
	string data = Stdio.read_file(argv[1]);
	//write("%O\n\n", data[..0x1077]); //First 4KB-plus-a-bit seems to be header??
	data = data[0x1078..];
	write("%O\n", data[..64]);
	int lastsize = 0;
	while (1)
	{
		write("Next data: %O\n", data[..32]);
		//Before the filename, there are some NUL bytes. It seems to be a minimum
		//of four, and then padding to a multiple of four; but not always the NEXT
		//multiple of four. Weird. Fortunately, the size of a file name is unlikely
		//to exceed 255 bytes, so we can just strip off all the zeroes.
		sscanf(data, "%[\0]%-4H%s", string zeroes, string filename, data);
		if (filename == "\1") break;
		//write("[%6x %x+%x=%x] NEXT FILE: %O\n", lastsize, lastsize%4, sizeof(zeroes), lastsize%4 + sizeof(zeroes), filename);
		//The file name is padded with zeroes. To what? Multiple of four I think?
		constant PAD = 4;
		int pad = PAD - sizeof(filename) % PAD;
		if (pad != PAD && data[..pad-1] == "\0"*pad) data = data[pad..];
		sscanf(data, "%-4H%s", string cur, string newdata);
		lastsize = sizeof(cur);
		if (argc > 2) Stdio.write_file(argv[2] + "/" + filename, cur);
		else write("%O %d bytes\n", filename, sizeof(cur));
		data = newdata;
	}
}
