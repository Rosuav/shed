int last_command = 0;
Stdio.Buffer data = Stdio.Buffer();
array notenames = "C C# D Eb E F F# G Ab A Bb B" / " ";
array colors = "1;31 1;35 1;34 1;36" / " ";
int lastvel = 64;
void parsemessage() {
	while (sizeof(data)) {
		Stdio.Buffer.RewindKey rewind = data->rewind_on_error();
		int command = data->read_int8();
		if (command < 128) {data->unread(1); command = last_command;} //Running status
		else last_command = command;
		array ev = ({command});
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
				ev += ({data->read_int8(), data->read_int8()});
				break;
			case 0xC0..0xCF: //Program change
			case 0xD0..0xDF: //Channel aftertouch
			case 0xF3:
				//One data byte.
				ev+=({data->read_int8()});
				break;
			case 0xF1: case 0xF4..0xF6: case 0xF8..0xFE: //System Common various
				//No data bytes.
				break;
			case 0xF0: case 0xF7: error("SysEx not currently supported\n");
			case 0xFF: //Meta event
				error("Meta event?? In a MIDI stream??\n");
		}
		rewind->release();
		if (ev[0] < 0x90 || (ev[0] < 0xA0 && ev[2] == 0)) {
			//write("Note off [%d] %s%d\n", (ev[0] & 15) + 1, notenames[ev[1] % 12], ev[1] / 12);
		} else if (ev[0] < 0xA0) {
			int delta = ev[2] - lastvel; lastvel = ev[2];
			//write("Note on  [%d] %s%d vel %d\n", (ev[0] & 15) + 1, notenames[ev[1] % 12], ev[1] / 12, ev[2]);
			//write("Note on  [%d] %s%d vel %+d\n", (ev[0] & 15) + 1, notenames[ev[1] % 12], ev[1] / 12, delta);
			write("\e[%sm%4s %s\e[0m\n", colors[ev[0] & 15], notenames[ev[1] % 12] + (ev[1] / 12), "*" * ev[2]);
		}
		else write("Event: %{%02X %}\n", ev);
	}
}

int main(int argc, array(string) argv) {
	Stdio.File dev = Stdio.File("/dev/midi7"); //TODO: Parameterize
	dev->set_buffer_mode(data, 0);
	dev->set_nonblocking(parsemessage);
	return -1;
}
