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

string reduce(string data, multiset tracks, multiset channels, int(1bit) lyrics, int(1bit) merge) {
	array(array(string|array(array(int|string)))) chunks = midilib->parsesmf(data);
	mapping mergedest = ([]);
	foreach (chunks; int i; [string id, array chunk]) if (id == "MTrk") {
		int(1bit) keep = 0;
		if (tracks[i]) keep = 1; //Track is kept by index, but check for the merge hack
		foreach (chunk; int ev; array data) {
			//data == ({delay, command[, args...]})
			int cmd = data[1];
			if (merge && (cmd == 0x95 || cmd == 0x97)) mergedest[cmd + 1] = i;
			if (mergedest[cmd]) {
				//HACK HACK HACK - undocumented --merge parameter
				//Merge chunks with channels 6 and 7 into a single chunk
				//Ditto channels 8 and 9
				//Adds in any note-on/note-off messages, but nothing else.
				//TODO: Figure out a way to make this less hacky, give it a good
				//UI, and make it a real feature.
				//First, filter the current chunk to just the note messages.
				array notes = ({ });
				int delay = 0;
				foreach (chunk, array data) {
					if (data[1] >= 0x80 && data[1] <= 0x9F) {
						data[0] += delay;
						delay = 0;
						notes += ({data});
					}
					else delay += data[0];
				}
				array arr1 = chunks[mergedest[cmd]][1], arr2 = notes;
				//Assume that the last event in each chunk is the End event, and ignore it
				//After all merging, we'll add an End at zero delta-time. (There won't be
				//an End event in the notes[] array, since it only contains note messages.)
				int next1 = 0, next2 = 0, stop1 = sizeof(arr1) - 1, stop2 = sizeof(arr2);
				array dest = ({ });
				while (next1 < stop1 && next2 < stop2) {
					if (arr1[next1][0] > arr2[next2][0]) {
						arr1[next1][0] -= arr2[next2][0];
						dest += ({arr2[next2++]});
					} else {
						arr2[next2][0] -= arr1[next1][0];
						dest += ({arr1[next1++]});
					}
				}
				//We've emptied one of the arrays; grab what's left from the other.
				while (next1 < stop1) dest += ({arr1[next1++]});
				while (next2 < stop2) dest += ({arr2[next2++]});
				//And add on the necessary end event.
				dest += ({arr1[-1]}); //TODO: Enforce that it has zero delta-time
				chunks[mergedest[cmd]][1] = dest;
				keep = 0;
				break;
			}
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
	string outdata = reduce(indata, parse_ranges(args->track), parse_ranges(args->channel), args->lyrics, args->merge);
	if (outfn) Stdio.write_file(outfn, outdata);
	else write("%s", outdata);
}
