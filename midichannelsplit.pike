object midilib = (object)"patchpatch.pike";

void audit(string fn)
{
	array(array(string|array(array(int|string)))) chunks;
	for (int channel = 0; channel < 16; ++channel) {
		if (catch {chunks = midilib->parsesmf(Stdio.read_file(fn));}) return;
		int keep = 0x90 | channel;
		int have_notes = 0;
		foreach (chunks; int i; [string id, array chunk]) if (id == "MTrk")
		{
			foreach (chunk; int ev; array data)
			{
				//data == ({delay, command[, args...]})
				int cmd = data[1];
				if (cmd == keep) have_notes = 1;
				if (cmd >= 0x90 && cmd <= 0x9F && cmd != keep)
					data[3] = 0; //Set the velocity to zero, making it a note-off
			}
		}
		if (have_notes)
		{
			string outfn;
			if (has_suffix(lower_case(fn), ".mid")) outfn = fn[..<4] + "_" + channel + ".mid";
			else if (has_suffix(lower_case(fn), ".kar")) outfn = fn[..<4] + "_" + channel + ".kar";
			else outfn = fn + ".chan" + channel;
			write("Creating: %s\n", outfn);
			Stdio.write_file(outfn, midilib->buildsmf(chunks));
		}
	}
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg) audit(arg);
}
