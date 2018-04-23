//Audit a MIDI file and try to track down stuck notes

object midilib = (object)"patchpatch.pike";

void audit(string data)
{
	array(array(string|array(array(int|string)))) chunks = midilib->parsesmf(data);
	//Currently audits each chunk separately. As long as there's no overlap
	//in channel usage, this should not be a problem. If it becomes an issue,
	//add an optional step here to flatten to SMF0.
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
				if (cmd < 0x90 || data[3] == 0)
				{
					//werror("[%d:%d] %d ==> -%X\n", i, ev, data[0], note);
					//It's a Note-Off (8x nn vv), or a Note-On with
					//a velocity of 0 (9x nn 00).
					if (!notes_down[note]) write("[%d:%d] Release of unstruck note %X\n", i, ev, note);
					m_delete(notes_down, note);
				}
				else
				{
					//werror("[%d:%d] %d ==> +%X\n", i, ev, data[0], note);
					if (notes_down[note]) write("[%d:%d] Restrike of playing note %X [struck %d]\n", i, ev, note, notes_down[note]);
					notes_down[note] = ev;
				}
			}
			/*else if (cmd == 255)
				werror("[%d:%d] %d ==> Meta %X %O\n", i, ev, data[0], data[2], data[3]);
			else
				werror("[%d:%d] %d ==>%{ %X%}\n", i, ev, data[0], data[1..]);*/
		}
		foreach (notes_down; int note; int pos)
		{
			write("[%d:%d] Note %X remaining struck till end of chunk\n", i, pos, note);
		}
		if (sizeof(channels)) write("Chunk %d - %d channels used:%{ %d%}\n", i, sizeof(channels), (array)channels);
	}
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg) audit(Stdio.read_file(arg));
}
