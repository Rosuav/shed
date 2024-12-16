//Run this script to upgrade a new save game to a New Game Plus with the unique mods loaded
constant label = ([
	//Lifted from https://reg2k.github.io/control-save-editor-beta/
	542507875: "GLOBAL_VARIABLE_MANAGER",
	897885379: "MISSION_MANAGER",
	948665365: "LOOT_DROP",
	1019016931: "VENDOR",
	1721202367: "PLAYER_PROPERTIES",
	2134335914: "EXPEDITION_MANAGER",
	2227510435: "TRIALS",
	2500542964: "TUTORIAL_MANAGER",
	3357797087: "OUTFIT",
	3388499232: "INVENTORY",
	4156221793: "ENCOUNTER_DIRECTOR",
]);

array(array) read_array(Stdio.Buffer chunk, string fmt) {
	int num = chunk->read_le_int(4);
	array ret = ({ });
	while (num--) ret += ({chunk->sscanf(fmt)});
	return ret;
}

array chunkstart = ({ });

void parse_inventory(array piece) {
	object chunk = Stdio.Buffer(piece[2]); chunk->read_only();
	int objectversion = chunk->read_le_int(4);
	array items = read_array(chunk, "%-4c%-8c%-4F%-4c%-8c%-4c"); //version, gid, param, overcharge, pid, qty
	write("%{Got an item: %[1]X (%[2].0f), PID %[4]d qty %[5]d\n%}", items);
	[int equipped] = chunk->sscanf("%-4c"); //read_le_int(4) won't read -1 correctly
	array persisted = read_array(chunk, "%-8c%-8c"); //gid, unknown
	array active = read_array(chunk, "%-4c%-4c%-4c"); //version, index, parent
	int unknown = objectversion >= 4 ? chunk->read_int8() : 0;
	//Mutate...
	items += ({
		//I have no idea how important the PIDs are. For now, picking arbitrary distinct numbers.
		//Uncomment whichever ones you want to have.
		//({4, 0x322e985e6b2bc054,  72.0, 0, 43100, 1}), //Damage +72% (better than I've ever seen)
		//({4, 0x322e985e6b2bc054,  60.0, 0, 43101, 1}), //Damage +60% (best I've ever seen)
		//({4, 0x20a48983004a0054, 100.0, 0, 43102, 1}), //Eternal Fire - Grip unique mod
		//({4, 0x04e50def20e48054,-100.0, 0, 43103, 1}), //One-Way Track - Shatter unique mod
		//({4, 0x2256ef6508184054, 500.0, 0, 43104, 1}), //Thin Space - Charge unique mod
		//({4, 0x2d353346ebf84054,-100.0, 0, 43105, 1}), //Custodial Readiness - Pierce unique mod
		//({4, 0x089c1f77ecf18054, 100.0, 0, 43106, 1}), //Spam Mail - Spin unique mod
		//({4, 0x22a72842ade64054,  50.0, 0, 43107, 1}), //Aerobics - unique player mod (health on evade)
	});
	//And rebuild.
	chunk = Stdio.Buffer();
	chunk->sprintf("%-4c%-4c%{%-4c%-8c%-4F%-4c%-8c%-4c%}", objectversion, sizeof(items), items);
	chunk->sprintf("%-4c%-4c%{%-8c%-8c%}%-4c%{%-4c%-4c%-4c%}", equipped, sizeof(persisted), persisted, sizeof(active), active);
	if (objectversion >= 4) chunk->add_int8(unknown);
	piece[2] = (string)chunk;
}

int main(int argc, array(string) argv) {
	string data = Stdio.read_file(argv[1]);
	if (!data) exit(1, "USAGE: pike %s filename\n", argv[0]);
	int totsz = sizeof(data);
	sscanf(data, "%-8c%-4c%-4H%c%-4c%-4c%s", int version, int crc, string filename, int scope, int unknown, int nchunks, data);
	array chunks = ({ });
	mapping chunkfinder = ([]);
	for (int i = 0; i < nchunks; ++i) {
		int start = totsz - sizeof(data);
		sscanf(data, "%-4c%-4c%-4H%s", int uidlow, int uid, string chunk, data);
		chunks += ({({uidlow, uid, chunk})});
		chunkfinder[label[uid]] = chunks[-1]; //Reference the array so the chunk can be more easily edited
		chunkstart += ({({start, label[uid]})});
	}
	//Make edits to the chunks, possibly including adding to inventory
	parse_inventory(chunkfinder->INVENTORY);
	data = sprintf("%-4H%c%-4c%-4c", filename, scope, unknown, nchunks);
	foreach (chunks, [int uidlow, int uid, string chunk])
		data = sprintf("%s%-4c%-4c%-4H", data, uidlow, uid, chunk);
	data = sprintf("%-8c%-4c%s", version, Crypto.Checksum.crc32(data), data);
	if (argc > 2) Stdio.write_file(argv[2], data);
}
