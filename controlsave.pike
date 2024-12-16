/* Run this script to upgrade a new save game to a New Game Plus with the unique mods loaded
Some useful weapon GIDs:

Weapon Mod Exquisite Eternal Fire 100
Unmistakable :)
0x20a48983004a0054n

Weapon Mod Exquisite DLC2 Shotgun specific Impact Cannon -100
Probably Single-Track whatever, the Shatter unique
0x4e50def20e48054n

Weapon Mod Exquisite DLC2 RL specific Folded Space 500
Should be the projectile speed boost
0x2256ef6508184054n

Weapon Mod Exquisite DLC2 Railgun specific Snap Charge -100
Custodial Readiness
0x2d353346ebf84054n

Weapon Mod Exquisite DLC2 SMG specific Devastator 100
Spam Mail?
0x89c1f77ecf18054n

Player Mod Exquisite Fleet Foot 50
Possibly health on evade?
0x22a72842ade64054n

Weapon Mod Legendary Damage eg 46, 48, 60
Should be a basic damage mod at high rarity
0x322e985e6b2bc054n

Weapon Mod Exquisite Specific Missile Blast Radius 98
Might not be a unique
0xf56a66e21fcc054n
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
int main(int argc, array(string) argv) {
	string data = Stdio.read_file(argv[1]);
	if (!data) exit(1, "USAGE: pike %s filename\n", argv[0]);
	sscanf(data, "%-8c%-4c%-4H%c%-4c%-4c%s", int version, int crc, string filename, int scope, int unknown, int nchunks, data);
	werror("%x %O\n", crc, filename);
	werror("Calculated CRC: %x\n", Crypto.Checksum.crc32(sprintf("%-4H%c%-4c%-4c%s", filename, scope, unknown, nchunks, data)));
	array chunks = ({ });
	for (int i = 0; i < nchunks; ++i) {
		sscanf(data, "%-4c%-4c%-4H%s", int uidlow, int uid, string chunk, data);
		werror("Chunk: %s (%d bytes, %d left)\n", label[uid] || "???", sizeof(chunk), sizeof(data));
		chunks += ({({uidlow, uid, chunk})});
	}
	//TODO: Make edits to the chunks, possibly including adding to inventory
	//TODO: Save back to a file and make it ready to load!
}
