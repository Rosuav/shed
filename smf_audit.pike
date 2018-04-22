//Audit a MIDI file and try to track down stuck notes

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
	if (!chunks || !sizeof(chunks) || chunks[0][0]!="MThd") return 0; //Not a valid MIDI file
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
				case 0x00..0x7F: error("Status byte expected. Running status with no previous status.\n");
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
				case 0xF0: case 0xF7: break; //SysEx not currently supported
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

void audit(string data)
{
	array(array(string|array(array(int|string)))) chunks = parsesmf(data);
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
