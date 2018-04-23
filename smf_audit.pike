//Audit a MIDI file and try to track down stuck notes

object midilib = (object)"patchpatch.pike";
int verbose = 0;

void audit(string fn)
{
	if (fn == "--verbose" || fn == "-v") {verbose = 1; return;}
	array(array(string|array(array(int|string)))) chunks;
	if (catch {chunks = midilib->parsesmf(Stdio.read_file(fn));}) return;
	//Currently audits each chunk separately. As long as there's no overlap
	//in channel usage, this should not be a problem. If it becomes an issue,
	//add an optional step here to flatten to SMF0.
	int changed = 0;
	foreach (chunks; int i; [string id, array chunk]) if (id == "MTrk")
	{
		multiset(int) channels = (<>);
		mapping(int:int) notes_down = ([]); //channel * 256 + note : event position
		foreach (chunk; int ev; array data)
		{
			//data == ({delay, command[, args...]})
			int cmd = data[1];
			if (cmd >= 0x80 && cmd <= 0xEF) channels[cmd & 15] = 1;
			if (cmd >= 0x80 && cmd <= 0x9F)
			{
				int note = ((cmd & 15) << 8) | data[2];
				int was_down = notes_down[note];
				if (cmd < 0x90 || data[3] == 0)
				{
					//werror("[%d:%d] %d ==> -%X\n", i, ev, data[0], note);
					//It's a Note-Off (8x nn vv), or a Note-On with
					//a velocity of 0 (9x nn 00).
					m_delete(notes_down, note);
					if (was_down) continue;
					if (verbose) write("[%d:%d] Release of unstruck note %X\n", i, ev, note);
				}
				else
				{
					//werror("[%d:%d] %d ==> +%X\n", i, ev, data[0], note);
					notes_down[note] = ev;
					if (!was_down) continue;
					if (verbose) write("[%d:%d] Restrike of playing note %X [struck %d]\n", i, ev, note, was_down);
				}
				//If we get here, there was a problem. Remove the faulty event; worst case, there's
				//a note missing somewhere.
				chunk[ev + 1][0] += chunk[ev][0]; //Transfer the time onto the next event (which might be the FF 2F 00 "End of track")
				chunk[ev] = 0;
				++changed;
			}
			/*else if (cmd == 255)
				werror("[%d:%d] %d ==> Meta %X %O\n", i, ev, data[0], data[2], data[3]);
			else
				werror("[%d:%d] %d ==>%{ %X%}\n", i, ev, data[0], data[1..]);*/
		}
		foreach (notes_down; int note; int pos)
		{
			if (verbose) write("[%d:%d] Note %X remaining struck till end of chunk\n", i, pos, note);
			//Maybe suppress these? Or maybe add explicit note-off messages?
		}
		//if (sizeof(channels)) write("Chunk %d - %d channels used:%{ %d%}\n", i, sizeof(channels), (array)channels);
	}
	if (changed)
	{
		string outfn;
		if (has_suffix(lower_case(fn), ".mid")) outfn = fn[..<4] + "_patched.mid";
		else if (has_suffix(lower_case(fn), ".kar")) outfn = fn[..<4] + "_patched.kar";
		else outfn = fn + ".patched";
		Stdio.write_file(outfn, midilib->buildsmf(chunks));
		write("%s: %d faulty commands removed\n", fn, changed);
	}
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg) audit(arg);
}
