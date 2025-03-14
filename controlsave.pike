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
	write("%{Got an item: 0x%016[1]x (%4[2].0f), PID %5[4]d qty %[5]d\n%}", items);
	[int equipped] = chunk->sscanf("%-4c"); //read_le_int(4) won't read -1 correctly
	array persisted = read_array(chunk, "%-8c%-8c"); //gid, unknown
	array active = read_array(chunk, "%-4c%-4c%-4c"); //version, index, parent
	int unknown = objectversion >= 4 ? chunk->read_int8() : 0;
	//Mutate...
	items += ({
		//I have no idea how important the PIDs are. For now, picking arbitrary distinct numbers.
		//Uncomment whichever ones you want to have.
		//The unique mods. These are the exact ones you would get during a playthrough; aside from
		//the first two, they come from DLC side missions. Most of them already have their values
		//as good as can be (eg Eternal Fire can't benefit from being above 100% chance), but you
		//could (say) boost the health gained by Aerobics if you want something extra special.
		//({4, 0x22a72842ade64054,  50.0, 0, 43101, 1}), //Aerobics - unique player mod (health on evade)
		//({4, 0x20a48983004a0054, 100.0, 0, 43102, 1}), //Eternal Fire - Grip unique mod
		//({4, 0x04e50def20e48054,-100.0, 0, 43103, 1}), //One-Way Track - Shatter unique mod
		//({4, 0x2256ef6508184054, 500.0, 0, 43104, 1}), //Thin Space - Charge unique mod
		//({4, 0x2d353346ebf84054,-100.0, 0, 43105, 1}), //Custodial Readiness - Pierce unique mod
		//({4, 0x089c1f77ecf18054, 100.0, 0, 43106, 1}), //Spam Mail - Spin unique mod

		//Regular mods, as good as they ever come. If I ever spot a randomly-generated mod with
		//better numbers than these, I'll update. Note that the rarity doesn't actually imply
		//anything about the quality, and you could theoretically have a lower rarity mod with
		//better numbers.
		//({4, 0x322e985e6b2bc054,  60.0, 0, 43201, 1}), //[Prm] Damage
		//({4, 0x137fa77cd2a14054,  36.0, 0, 43202, 1}), //[Prm] Spin rate of fire boost
		//({4, 0x268ad8821bf98054,  63.0, 0, 43203, 1}), //[Rar] Headshot Damage
		//({4, 0x24f564d1bb194054,  29.0, 0, 43204, 1}), //[Abs] Spin Grouping Efficiency
		//({4, 0x2b8e23e8eb2d0054,  42.0, 0, 43205, 1}), //[Abs] Pierce Aimed Fire Boost
		//({4, 0x02c3b6c628f4c054, -25.0, 0, 43206, 1}), //[Prm] Levitation Ammo Efficiency (one of the few ammo cost reductions that works on Pierce)
		//({4, 0x2b7de92445e0c054,   9.0, 0, 43207, 1}), //[Rar] Accuracy
		//({4, 0x3aae75a1827d8054,   7.0, 0, 43208, 1}), //[Abs] Shatter Projectile Boost
		//({4, 0x282d8e0d682f0054,  95.0, 0, 43209, 1}), //[Abs] Consecutive Kills Boost
		//({4, 0x0fe906cd12db8054, -24.0, 0, 43210, 1}), //[Abs] Dodge Efficiency
		//({4, 0x3db45158abde0054, -24.0, 0, 43211, 1}), //[Abs] Shield Efficiency
		//({4, 0x18319f9ca0820054, -25.0, 0, 43212, 1}), //[Abs] Launch Efficiency
		//({4, 0x233eeade10c9c054,  93.0, 0, 43213, 1}), //[Abs] Seize Accelerator
		//({4, 0x2c5e8b91ca40c054,  58.0, 0, 43214, 1}), //[Abs] Health Recovery (per element pick-up)
		//({4, 0x2c56b490927b4054,  31.0, 0, 43215, 1}), //[Prm] Health Boost
		//({4, 0x26b40c2259bec054,  10.0, 0, 43216, 1}), //[Rar] Energy Boost
		//({4, 0x0f32b53616d18054, -28.0, 0, 43217, 1}), //[Inf] Seized Protection (damage reduction when you seize an enemy)
		//({4, 0x1ef91ec87bb3c054, 101.0, 0, 43218, 1}), //[Inf] Charge Blast Boost (blast radius)

		//Regular mods, but better than they have ever been seen. Super-powered mods.
		//({4, 0x322e985e6b2bc054,  72.0, 0, 43301, 1}), //[Prm] Damage
		//({4, 0x2c56b490927b4054,  50.0, 0, 43302, 1}), //[Prm] Health Boost
		//({4, 0x02c3b6c628f4c054,-100.0, 0, 43206, 1}), //[Prm] Levitation Ammo Efficiency (free bullets while levitating?)
		//({4, 0x0fe906cd12db8054,-100.0, 0, 43210, 1}), //[Abs] Dodge Efficiency
		//({4, 0x18319f9ca0820054,-100.0, 0, 43212, 1}), //[Abs] Launch Efficiency
	});
	//And rebuild.
	chunk = Stdio.Buffer();
	chunk->sprintf("%-4c%-4c%{%-4c%-8c%-4F%-4c%-8c%-4c%}", objectversion, sizeof(items), items);
	chunk->sprintf("%-4c%-4c%{%-8c%-8c%}%-4c%{%-4c%-4c%-4c%}", equipped, sizeof(persisted), persisted, sizeof(active), active);
	if (objectversion >= 4) chunk->add_int8(unknown);
	piece[2] = (string)chunk;
}

int main(int argc, array(string) argv) {
	void usage() {exit(1, #"USAGE: pike %s filename
The save files are stored in Steam's remote save path, eg:
	~/.steam/steam/userdata/<steamid>/870780/remote
This script generally gives best results on *persistent.sav
", argv[0]);}
	if (argc <= 1) usage();
	string data = Stdio.read_file(argv[1]);
	if (!data) usage();
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
