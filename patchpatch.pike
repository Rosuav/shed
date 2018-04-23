string patches=#"
0x00 Acoustic Grand Piano     0x2B Contrabass          0x56 Lead 7 (fifths)
0x01 Bright Acoustic Piano    0x2C Tremolo Strings     0x57 Lead 8 (bass+lead
0x02 Electric Grand Piano     0x2D Pizzicato Strings   0x58 Pad 1 (new age)
0x03 Honky-tonk Piano         0x2E Orchestral Harp     0x59 Pad 2 (warm)
0x04 Electric Piano 1         0x2F Timpani             0x5A Pad 3 (polysynth)
0x05 Electric Piano 2         0x30 String Ensemble 1   0x5B Pad 4 (choir)
0x06 Harpsichord              0x31 String Ensemble 2   0x5C Pad 5 (bowed)
0x07 Clavinet                 0x32 SynthStrings 1      0x5D Pad 6 (metallic)
0x08 Celesta                  0x33 SynthStrings 2      0x5E Pad 7 (halo)
0x09 Glockenspiel             0x34 Choir Aahs          0x5F Pad 8 (sweep)
0x0A Music Box                0x35 Voice Oohs          0x60 FX 1 (train)
0x0B Vibraphone               0x36 Synth Voice         0x61 FX 2 (soundtrack)
0x0C Marimba                  0x37 Orchestra Hit       0x62 FX 3 (crystal)
0x0D Xylophone                0x38 Trumpet             0x63 FX 4 (atmosphere)
0x0E Tubular Bells            0x39 Trombone            0x64 FX 5 (brightness)
0x0F Dulcimer                 0x3A Tuba                0x65 FX 6 (goblins)
0x10 Drawbar Organ            0x3B Muted Trumpet       0x66 FX 7 (echoes)
0x11 Percussive Organ         0x3C French Horn         0x67 FX 8 (sci-fi)
0x12 Rock Organ               0x3D Brass Section       0x68 Sitar
0x13 Church Organ             0x3E Synth Brass 1       0x69 Banjo
0x14 Reed Organ               0x3F Synth Brass 2       0x6A Shamisen
0x15 Accordion                0x40 Soprano Sax         0x6B Koto
0x16 Harmonica                0x41 Alto Sax            0x6C Kalimba
0x17 Tango Accordion          0x42 Tenor Sax           0x6D Bagpipe
0x18 Acoustic Guitar (nylon)  0x43 Baritone Sax        0x6E Fiddle
0x19 Acoustic Guitar (steel)  0x44 Oboe                0x6F Shanai
0x1A Electric Guitar (jazz)   0x45 English Horn        0x70 Tinkle Bell
0x1B Electric Guitar (clean)  0x46 Bassoon             0x71 Agogo
0x1C Electric Guitar (muted)  0x47 Clarinet            0x72 Steel Drums
0x1D Overdriven Guitar        0x48 Piccolo             0x73 Woodblock
0x1E Distortion Guitar        0x49 Flute               0x74 Tailo Drum
0x1F Guitar Harmonics         0x4A Recorder            0x75 Melodic Drum
0x20 Acoustic Bass            0x4B Pan Flute           0x76 Synth Drum
0x21 Electric Bass (finger)   0x4C Blown Bottle        0x77 Reverse Cymbal
0x22 Electric Bass (pick)     0x4D Shakuhachi          0x78 Guitar Fret Noise
0x23 Fretless Bass            0x4E Whistle             0x79 Breath Noise
0x24 Slap Bass 1              0x4F Ocarina             0x7A Seashore
0x25 Slap Bass 2              0x50 Lead 1 (square)     0x7B Bird Tweet
0x26 Synth Bass 1             0x51 Lead 2 (sawtooth)   0x7C Telephone Ring
0x27 Synth Bass 2             0x52 Lead 3 (calliope)   0x7D Helicopter
0x28 Violin                   0x53 Lead 4 (chiff)      0x7E Applause
0x29 Viola                    0x54 Lead 5 (charang)    0x7F Gunshot
0x2A Cello                    0x55 Lead 6 (voice)

0 Violin 2
1 Violin 1
2 Violin Pizz
3 Violin con Sordino
4 Violin Tremolo
5 Viola Section
6 Viola Trem
7 Viola con Sordino
8 Viola Pizz
9 Cello Section
10 Cello Pizz
11 Cello con Sordino
12 Cello Trem
13 Bass Sect
14 Bass Pizz
15 Bass Trem
16 Flute
17 Piccolo
18 Clarinet
19 Alternate cello patch
20 Oboe
21 Oboe d'Amore
22 Bassoon
23 French Horn
24 F Horn mute
25 Trumpet
26 Trombone
27 Percussion
28 - 30 Blank
31 Glockenspeil
32 Solo Violin
33 Solo violin 2
34 Solo Cello
35 Tubular bells
36 Trumpet Cup Mute
37 Trumpet Harmon Mute
38 Trumpet section mutes
39 Cello section 2 or 3
";

//Parse the first byte(s) of data and return a variable-length integer and the remaining data. Not the fastest algorithm but it's cool :)
array(int|string) getvarlen(string data)
{
	sscanf(data,"%[\x80-\xFF]%c%s",string extralen,int len,data);
	sscanf(sprintf("%{%7.7b%}%07b",(array(int))extralen,len),"%b",len);
	return ({len,data});
}

//Parse a Standard MIDI File and return an array of chunks
//Each chunk has its four-letter type, and then either a string of content or an array of messages.
//Each message is an array of integers or strings: ({int delay, int command, int|string ... parameters)}
//The parameters are normally integers, but meta events may use strings.
array(array(string|array(array(int|string)))) parsesmf(string data)
{
	sscanf(data,"%{%4s%4H%}",array(array(string|array(array(int|string)))) chunks); //Now *that's* a REAL variable declaration. Hehe! :)
	foreach (chunks,array(string|array(array(int|string))) chunk)
	{
		if (chunk[0]!="MTrk") continue;
		array(array(int|string)) events=({ });
		string data=[string]chunk[1];
		int command=0;
		while (data!="")
		{
			[int delay,data]=getvarlen(data);
			if (data[0]>=128) {command=data[0]; data=data[1..];} //If it isn't, retain running status. Note that information is not retained as to the use of running status.
			array(int|string) ev=({delay,command});
			switch (command)
			{
				case 0x00..0x7F: return 0; //Error - status byte expected. Running status with no previous status.
				case 0x80..0x8F: //Note off
				case 0x90..0x9F: //Note on
				case 0xA0..0xAF: //Note aftertouch
				case 0xB0..0xBF: //Controller
				case 0xE0..0xEF: //Pitch bend
				case 0xF2: //Song Position
					//Two data bytes for these
					ev+=({data[0],data[1]});
					data=data[2..];
					break;
				case 0xC0..0xCF: //Program change
				case 0xD0..0xDF: //Channel aftertouch
				case 0xF3:
					//One data byte.
					ev+=({data[0]});
					data=data[1..];
					break;
				case 0xF1: case 0xF4..0xF6: case 0xF8..0xFE: //System Common various
					//No data bytes.
					break;
				case 0xF0: case 0xF7: return 0; //SysEx not currently supported
				case 0xFF: //Meta event
					[int type,int len,data]=({data[0],@getvarlen(data[1..])});
					string meta=data[..len-1]; data=data[len..];
					ev+=({type,meta});
					break;
			}
			events+=({ev});
		}
		chunk[1]=events;
	}
	return chunks;
}

//Inverse of getvarlen; make a string of the given varlen integer.
string makevarlen(int len)
{
	array(int) ret=({len&127}); len>>=7;
	while (len) {ret=({len&127|128})+ret; len>>=7;}
	return (string)ret;
}

//Inverse of parsesmf; take an array of chunks as returned by parsesmf and return the corresponding SMF data.
//Perfect round-trip is not guaranteed; if the input data does not use running status, then buildsmf(parsesmf(data)) will be shorter than the original.
//But the output of buildsmf is guaranteed to be _equivalent to_ the input to parsesmf.
//Note that the input data is assumed to be correct; mismatching status bytes and the number of data bytes following will result in a corrupt MIDI file.
string buildsmf(array(array(string|array(array(int|string)))) chunks)
{
	foreach (chunks,array(string|array(array(int|string))) chunk)
	{
		if (!arrayp(chunk[1])) continue;
		array(string) data=({ });
		int laststatus=0;
		foreach (chunk[1],array(int|string|array) ev)
		{
			if (!ev) continue; //Allow zeroing out of events to completely remove them
			if (ev[1]==0xFF)
			{
				data+=({sprintf("%s\xFF%c%s%s",makevarlen(ev[0]),ev[2],makevarlen(sizeof(ev[3])),ev[3])});
				continue;
			}
			data+=({makevarlen(ev[0])+(string)ev[1+(ev[1]==laststatus)..]}); //Skip the status byte if it's the same as the previous
			laststatus=ev[1];
		}
		chunk[1]=data*"";
	}
	return sprintf("%{%4s%4H%}",chunks);
}

void patch(string fn)
{
	string data=Stdio.read_bytes(fn);
	array(array(string|array(array(int|string)))) chunks=parsesmf(data);
	//Now we go ahead and mutate chunks
	mapping(int:int) percussion=([
		0x2B:0x23, //Bass drum [F]
		0x2C:0x24, //Bass drum [P]
		0x32:0x26, //Snare (?)
		0x33:0x26, //Snare (?)
		0x54:0x51, //Triangle
	]);
	mapping(int:int) patch=([
		0x11:0x48, //Piccolo
		0x10:0x49, //Flute
		0x14:0x44, //Oboe
		0x12:0x47, //Clarinet
		0x16:0x46, //Bassoon
		0x19:0x3C, //"\tCornets in A" --> French Horn
		0x17:0x45, //"Horn in F" --> English Horn
		0x1A:0x39, //Trombone
		0x1B:0x00, //Percussion (set to "Standard")
		0x01:0x28, //"Violini 1 "
		0x00:0x28, //"Violini 2"
		0x20:0x28, //"String Solos"
		0x05:0x29, //"Violi"
		0x09:0x2A, //"Celli"
		0x0D:0x2B, //"Bassi"
		0x04:0x2C,0x06:0x2C,0x0C:0x2C,0x0F:0x2C, //Tremolo violin/viola/cello
		0x02:0x2D,0x08:0x2D,0x0A:0x2D,0x0E:0x2D, //Pizzicato violin/viola/cello/bass
	]);
	constant suppressunknown=1; //If true, unknown percussion elements will be suppressed instead of left unchanged.
	//for (int i=0;i<128;++i) patch[i]=percussion[i]=i; //Disable all translation and display of "Unknown"
	mapping(int:string) lyrics=([]);
	foreach (chunks,array(string|array(array(int|string))) chunk)
	{
		if (!arrayp(chunk[1])) continue;
		array(array(int|string)) insertme=allocate(sizeof(chunk[1])); //Insert events into current track (not used)
		int pos=0;
		string track="??";
		foreach (chunk[1];int idx;array(int|string) ev)
		{
			pos+=ev[0];
			switch (ev[1])
			{
				case 0x89: case 0x99:
					//if (ev[1]==0x99 && ev[3]) insertme[idx]=({0,0xFF,0x05,sprintf("%02X ",ev[2])});
					if (ev[1]==0x99 && ev[3]) lyrics[pos]=(lyrics[pos]||"")+sprintf(" %02X",ev[2]); 
					if (zero_type(percussion[ev[2]])) {write("Unknown percussion: %02X\n",ev[2]); percussion[ev[2]]=suppressunknown?-1:ev[2];}
					if (percussion[ev[2]]==-1) ev[2]=ev[3]=0; //Silence them by turning Note Ons into Note Offs for note 0. Should work, I hope, assuming that note 0 isn't used.
					else ev[2]=percussion[ev[2]];
					break;
				case 0xFF: if (ev[2]==0x03) write("Track: %s\n",track=ev[3]); break;
				case 0xC0..0xCF:
					//insertme[idx]=({0,0xFF,0x05,sprintf("\nPatch %02X->%02X",ev[2],patch[ev[2]])});
					if (pos) lyrics[pos]=(lyrics[pos]?lyrics[pos]+"; ":"\n")+sprintf("%s->%02X",track,ev[2]);
					if (zero_type(patch[ev[2]])) {write("Unknown patch: %02X\n",ev[2]); patch[ev[2]]=ev[2];}
					else ev[2]=patch[ev[2]];
					break;
				default: break;
			}
		}
		chunk[1]=Array.splice(chunk[1],insertme)-({0});
	}
	chunks[0][1][3]=sizeof(chunks);
	array(array(int|string)) events=({ });
	int lastpos=0;
	foreach (sort(indices(lyrics)),int pos)
	{
		events+=({ ({pos-lastpos,0xFF,0x05,lyrics[pos]}) });
		lastpos=pos;
	}
	chunks+=({({"MTrk",events+({({0,0xFF,0x2F,""})})})});
	Stdio.File(fn+".mid","wct")->write(buildsmf(chunks));
}

int main(int argc,array(string) argv)
{
	if (argv[1]=="all")
	{
		//Special hack for Midi Opera Co filenaming convention: process all files that don't have a recognized extension
		foreach (filter(get_dir("."),lambda(string fn) {return !(<"mid","mp3">)[(fn/".")[-1]];}),string fn)
		{
			write("\nPatching: %s\n",fn);
			patch(fn);
		}
	}
	else patch(argv[1]);
}
