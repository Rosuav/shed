/* Run this script to upgrade a new save game to a New Game Plus with the unique mods loaded
Some useful weapon GIDs:

Weapon Mod Exquisite Eternal Fire 100
Unmistakable :)
0x20a48983004a0054

Weapon Mod Exquisite DLC2 Shotgun specific Impact Cannon -100
Probably Single-Track whatever, the Shatter unique
0x4e50def20e48054

Weapon Mod Exquisite DLC2 RL specific Folded Space 500
Should be the projectile speed boost
0x2256ef6508184054

Weapon Mod Exquisite DLC2 Railgun specific Snap Charge -100
Custodial Readiness
0x2d353346ebf84054

Weapon Mod Exquisite DLC2 SMG specific Devastator 100
Spam Mail?
0x89c1f77ecf18054

Player Mod Exquisite Fleet Foot 50
Possibly health on evade?
0x22a72842ade64054

Weapon Mod Legendary Damage eg 46, 48, 60
Should be a basic damage mod at high rarity
0x322e985e6b2bc054

Weapon Mod Exquisite Specific Missile Blast Radius 98
Might not be a unique
0xf56a66e21fcc054
*/

/* Structure of one inventory item:
4 Version (always four)
8 GID
4 Parameter (float)
4 Overcharge Normalized Value (always zero)
8 PID <== this one seems to be essential
4 Qty
*/
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
