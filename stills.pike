//Add stills to an image
/*
pike stills.pike VID_20150403_175656533.mp4 3:2=Sikorsky.png 7:2=Sikorsky.png overlaid.mkv
Will overlay Sikorsky.png at timestamp 3 for 2 seconds, then at timestamp 7 for 2 seconds.

Creates a boatload of temporary files, all matching glob "part*"; will delete everything
matching that glob on termination, including any that it didn't create. You have been warned.
*/

//From bluray2mkv
array(Stdio.File) closeme=({ });
void multirun(array(string) cmd,array(string) inputs,mapping modifiers)
{
	Stdio.File mystdin = Stdio.File();
	Process.create_process(cmd, modifiers + (["stdin": mystdin->pipe(Stdio.PROP_IPC|Stdio.PROP_REVERSE)]));
	Shuffler.Shuffle sf = Shuffler.Shuffler()->shuffle(mystdin);
	closeme=Stdio.File(inputs[*]);
	sf->add_source(closeme[*]);
	sf->set_done_callback(lambda () {catch {mystdin->close();};});
	sf->start();
}

void cleanup()
{
	rm(glob("part*",get_dir())[*]);
	exit(0);
}

int main(int argc,array(string) argv)
{
	if (argc<3) exit(1,"Check source code for usage\n");
	string input=argv[1],output=argv[-1];
	array(string) avconv=({"avconv","-i",input});
	int pos=0;
	array(string) files=({ });
	array(string) combineme=({ });

	//Start by getting the video dimensions.
	array(int) video_dimensions;
	string info=Process.run(avconv)->stderr;
	sscanf(info,"%*sVideo: %s\n",string vid);
	foreach (vid/", ", string attr) if (sscanf(attr,"%dx%d",int x,int y) && attr==sprintf("%dx%d",x,y)) video_dimensions=({x,y});
	if (!video_dimensions) exit(1,"Unable to calculate video dimensions!\n");

	foreach (argv[2..<1];int idx;string image)
	{
		sscanf(image,"%d:%d=%s",int start,int len,string fn);
		if (!fn) exit(1,"Check source code for usage (unable to parse %O)\n",image);
		avconv+=({"-t",(string)(start-pos),sprintf("part%dA.ts",idx),"-ss",(string)start,"-t",(string)len,sprintf("part%dB.mkv",idx),"-ss",(string)(start+len)});
		pos=start+len;
		files+=({fn}); combineme+=({sprintf("part%dA.ts",idx),sprintf("part%dB.ts",idx)});
	}
	avconv+=({"partC.ts"}); combineme+=({"partC.ts"});
	Process.create_process(avconv)->wait();
	foreach (files;int idx;string fn)
	{
		Image.Image img=Image.decode(Stdio.read_file(fn));
		if (!img) write("Unable to parse image to decode: %O\n",fn);
		float xscale=(float)(video_dimensions[0])/img->xsize();
		float yscale=(float)(video_dimensions[1])/img->ysize();
		img = img->scale(min(xscale,yscale)); //This will result in an image that's either exactly right, or too small.
		img = img->copy(0, 0, video_dimensions[0]-1, video_dimensions[1]-1);
		Stdio.write_file("partD.png", Image.PNG.encode(img));
		Process.create_process(({"avconv","-i",sprintf("part%dB.mkv",idx),"-i","partD.png","-filter_complex","overlay","partD.mkv"}))->wait();
		Process.create_process(({"avconv","-i","partD.mkv",sprintf("part%dB.ts",idx)}))->wait();
		rm("partD.mkv");
	}
	rm(output);
	multirun(({"avconv","-i","-","-c","copy",output}),combineme,(["callback":cleanup]));
	return -1;
}
