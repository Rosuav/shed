/* Multi-file unzip, NOT using the external unzip command.
Mainly exists as an experiment in streaming Gz, Stdio.Buffer, System.Memory, etc.
It does, however, appear capable of unzipping certain (possibly malformed) files that unzip(1) won't.
*/

//Unzip the specified data (should be exactly what could be read from/written to a .zip file)
//and call the callback for each file, with the file name, contents, and the provided arg.
//Note that content errors will be thrown, but previously-parsed content has already been
//passed to the callback. This may be considered a feature.
//Note that this can't cope with prefixed zip data (eg a self-extracting executable).
void unzip(Stdio.Buffer data)
{
	werror("Extraction begins: %s\n",String.int2size(sizeof(data)));
	if (data->read(4)=="PK\5\6") return; //File begins with EOCD marker, must be empty.
	data->unread(4); //Simplify the loop by putting the marker back.
	while (data->read(4)=="PK\3\4")
	{
		[int minver,int flags,int method,int modtime,int moddate,int crc32,
			int compsize,int uncompsize,int fnlen,int extralen]
			= data->sscanf("%-2c%-2c%-2c%-2c%-2c%-4c%-4c%-4c%-2c%-2c");
		string fn=data->read(fnlen); //I can't use %-2H for these, because the two lengths come first and then the two strings. :(
		werror("... reading %s\n",fn);
		string extra=data->read(extralen); //Not actually used, and I have no idea whether it'll ever be important to Gypsum update.
		string|Stdio.Buffer zip=compsize?data->read(compsize):"";
		if (flags&8) {zip=data; data=0;} //compsize will be 0 in this case, and the zipped data will be the Stdio.Buffer.
		werror("Extracting %s...\n",fn);
		if (fn[-1]=='/') mkdir(fn);
		string result,eos;
		switch (method)
		{
			case 0: result=zip; eos=""; break; //Stored (incompatible with flags&8 mode)
			case 8:
			{
				object infl=Gz.inflate(-15);
				Stdio.File out=Stdio.File(fn,"wct");
				Stdio.Buffer buf=stringp(zip)?Stdio.Buffer(zip):zip;
				int csz=0,dsz=0;
				while (!infl->end_of_stream())
				{
					string c=buf->try_read(1048576*16);
					string d=infl->inflate(c);
					out->write(d);
					write("%s %s %d %d       \r",String.int2size(csz+=sizeof(c)),String.int2size(dsz+=sizeof(d)),sizeof(c),sizeof(buf));
				}
				eos=infl->end_of_stream() + (string)buf;
				break;
			}
			default: error("Unknown compression method %d (%s)",method,fn); 
		}
		if (flags&8)
		{
			//The next block should be the CRC and size marker, optionally prefixed with "PK\7\b". Not sure
			//what happens if the crc32 happens to be exactly those four bytes and the header's omitted...
			if (eos[..3]=="PK\7\b") eos=eos[4..]; //Trim off the marker
			sscanf(eos,"%-4c%-4c%-4c%s",crc32,compsize,uncompsize,string newdata);
			data=Stdio.Buffer(newdata);
		}
		else if (eos!="") error("Malformed ZIP file (bad end-of-stream on %s)",fn);
	}
	if (data->read(4)!="PK\1\2") error("Malformed ZIP file (bad signature)");
	//At this point, 'data' contains the central directory and the end-of-central-directory marker.
	//The EOCD contains the file comment, which may be of interest, but beyond that, we don't much care.
}

/*
void unzip(string data)
{
	if (has_prefix(data,"PK\5\6")) return; //File begins with EOCD marker, must be empty.
	werror("Extraction begins: %s\n",String.int2size(sizeof(data)));
	while (sscanf(data,"PK\3\4%-2c%-2c%-2c%-2c%-2c%-4c%-4c%-4c%-2c%-2c%s",
		int minver,int flags,int method,int modtime,int moddate,int crc32,
		int compsize,int uncompsize,int fnlen,int extralen,data))
	{
		string fn=data[..fnlen-1]; data=data[fnlen..]; //I can't use %-2H for these, because the two lengths come first and then the two strings. :(
		string extra=data[..extralen-1]; data=data[extralen..]; //Not actually used, and I have no idea whether it'll ever be important to Gypsum update.
		string zip=data[..compsize-1]; data=data[compsize..];
		if (flags&8) {zip=data; data=0;} //compsize will be 0 in this case.
		werror("Extracting %s...\n",fn);
		if (fn[-1]=='/') mkdir(fn);
		string eos;
		switch (method)
		{
			case 0: Stdio.write_file(fn,zip); eos=""; break; //Stored (incompatible with flags&8 mode)
			case 8:
			{
				object infl=Gz.inflate(-15);
				Stdio.File out=Stdio.File(fn,"wct");
				Stdio.Buffer buf=Stdio.Buffer(zip);
				werror("%s vs %s\n",String.int2size(sizeof(buf)),String.int2size(sizeof(zip)));
				int csz=0,dsz=0;
				while (!infl->end_of_stream())
				{
					string c=buf->try_read(1048576*16);
					string d=infl->inflate(c);
					out->write(d);
					write("%s %s      %d %d       \r",String.int2size(csz+=sizeof(c)),String.int2size(dsz+=sizeof(d)),sizeof(c),sizeof(buf));
				}
				eos=infl->end_of_stream() + (string)buf;
				break;
			}
			default: error("Unknown compression method %d (%s)",method,fn); 
		}
		if (flags&8)
		{
			//The next block should be the CRC and size marker, optionally prefixed with "PK\7\b". Not sure
			//what happens if the crc32 happens to be exactly those four bytes and the header's omitted...
			if (eos[..3]=="PK\7\b") eos=eos[4..]; //Trim off the marker
			sscanf(eos,"%-4c%-4c%-4c%s",crc32,compsize,uncompsize,data);
		}
		else if (eos!="") error("Malformed ZIP file (bad end-of-stream on %s)",fn);
	}
	if (data[..3]!="PK\1\2") error("Malformed ZIP file (bad signature)");
	//At this point, 'data' contains the central directory and the end-of-central-directory marker.
	//The EOCD contains the file comment, which may be of interest, but beyond that, we don't much care.
}
*/

int main(int argc,array(string) argv)
{
	foreach (argv[1..],string fn)
	{
		werror("Loading %s\n",fn);
		//unzip(Stdio.read_file(fn));
		unzip(Stdio.Buffer(System.Memory(fn)));
	}
}
