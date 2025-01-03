object midilib = (object)"patchpatch.pike";

constant USAGE = #"USAGE: pike %s [--track=N-M,..] [--channel=N-M,...] [--lyrics] [infile outfile]

track N keeps the MIDI track numbered N (starting from 1)

channel N keeps any MIDI track containing a Note-On for channel N
(identified by 1-16)

N can be specified as N-M for a range of channels/tracks, and multiple
ranges can be specified with commas eg --channel=6,7-9

At least one of --track and --channel must be specified.

Specify --lyrics to retain any chunk containing Lyric events (FF 05).

If file names are not specified, reads stdin and writes stdout.
";

string reduce(string data, multiset tracks, multiset channels, int(1bit) lyrics) {
	array(array(string|array(array(int|string)))) chunks = midilib->parsesmf(data);
	foreach (chunks; int i; [string id, array chunk]) if (id == "MTrk") {
		if (tracks[i]) continue; //Track is kept by index, no need to scan
		int(1bit) keep = 0;
		foreach (chunk; int ev; array data) {
			//data == ({delay, command[, args...]})
			int cmd = data[1];
			if (cmd >= 0x90 && cmd <= 0x9F && channels[1 + (cmd&15)]) {
				keep = 1;
				break;
			}
			if (cmd == 0xFF && data[2] == 5 && lyrics) {
				keep = 1;
				break;
			}
		}
		if (!keep) chunks[i] = 0;
	}
	chunks -= ({0});
	sscanf(chunks[0][1], "%2c%2c%2c", int typ, int trks, int timing);
	chunks[0][1] = sprintf("%2c%2c%2c", typ, sizeof(chunks) - 1, timing);
	return midilib->buildsmf(chunks);
}

multiset parse_ranges(string|zero ranges) {
	if (!ranges) return (<>);
	multiset ret = (<>);
	foreach (ranges / ",", string r) {
		sscanf(r, "%d-%d", int start, int stop);
		if (!start) continue;
		if (!stop) stop = start;
		while (start <= stop) ret[start++] = 1;
	}
	return ret;
}

int main(int argc, array(string) argv) {
	mapping args = Arg.parse(argv);
	string infn, outfn;
	switch (sizeof(args[Arg.REST])) {
		case 0: break; //Read stdin, write to stdout
		//case 1: //Should it read the file and mutate?
		case 2: [infn, outfn] = args[Arg.REST]; break;
		default: exit(1, USAGE, argv[0]);
	}
	if (!args->channel && !args->track) exit(1, USAGE, argv[0]);
	string indata = infn ? Stdio.read_file(infn) : Stdio.stdin.read();
	if (!indata || indata == "") exit(1, USAGE, argv[0]);
	string outdata = reduce(indata, parse_ranges(args->track), parse_ranges(args->channel), args->lyrics);
	if (outfn) Stdio.write_file(outfn, outdata);
	else write("%s", outdata);
}
