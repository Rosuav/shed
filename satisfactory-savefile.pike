//I know the AnthorNet tool can read these files, but I'm starting fresh
//Main goal: List all detritus and all hard drive requirements.
//1) Does detritus get added to the savefile only once you approach it?
//2) Is detritus always the same - that is, is initial item distribution part of the map, or randomized?
//3) Can I see some marker that says "this sector hasn't had its items loaded in yet"?

//Strings are stored as null-terminated Hollerith strings, which seems redundant. (The null is included in the length.)
//Integers, including string lengths, are all 32-bit little-endian.


//Total of all hard drive requirements, not counting power
//This is cribbed from https://satisfactory-calculator.com/en/hard-drives as I haven't figured out where that's stored
//in the save file; in fact, it may not be, and the information may need to be parsed from the map elsewhere instead.
constant HARD_DRIVE_REQUIREMENTS = ([
	"Desc_SteelPlate_C": 150, //Steel Beam
	"Desc_ElectromagneticControlRod_C": 84,
	"Desc_Silica_C": 70,
	"Desc_Rubber_C": 70,
	"Desc_CoolingSystem_C": 65,
	"Desc_HighSpeedWire_C": 63,
	"Desc_Plastic_C": 60,
	"Desc_AluminumPlate_C": 57, //Alclad Sheet
	"Desc_AluminumPlateReinforced_C": 54, //Heat Sink
	"Desc_MotorLightweight_C": 41, //Turbo Motor
	"Desc_CopperSheet_C": 40,
	"Desc_ModularFrame_C": 37,
	"Desc_HighSpeedConnector_C": 35,
	"Desc_QuartzCrystal_C": 32,
	"Desc_SteelPlateReinforced_C": 30, //Encased Beam
	"Desc_Motor_C": 30,
	"Desc_Rotor_C": 27,
	"Desc_ModularFrameHeavy_C": 26,
	"Desc_IronScrew_C": 25,
	"Desc_CrystalOscillator_C": 20,
	"Desc_Computer_C": 16,
	"Desc_CircuitBoard_C": 15,
	"Desc_AluminumCasing_C": 15,
	"Desc_ModularFrameFused_C": 12,
	"Desc_Stator_C": 10,
	"Desc_Biofuel_C": 10,
	"Desc_IronRod_C": 5,
	"Desc_IronPlateReinforced_C": 5,
	"Desc_Gunpowder_C": 2,
	"Desc_QuantumOscillator_C": 1, //Superposition Oscillator
]);

constant ITEM_NAMES = ([
	"Desc_AluminumPlateReinforced_C": "Heat Sink",
	"Desc_AluminumPlate_C": "Alclad Aluminum Sheet",
	"Desc_Biofuel_C": "Solid Biofuel",
	"Desc_CartridgeSmart_C": "Unknown 'Cartridge Smart'",
	"Desc_CartridgeStandard_C": "Rifle Ammo",
	"Desc_Cement_C": "Concrete",
	"Desc_ComputerSuper_C": "Supercomputer",
	"Desc_Filter_C": "Gas Filter",
	"Desc_Fuel_C": "Packaged Fuel",
	"Desc_HighSpeedConnector_C": "High-Speed Connector",
	"Desc_HighSpeedWire_C": "Quickwire",
	"Desc_IronPlateReinforced_C": "Reinforced Iron Plate",
	"Desc_IronScrew_C": "Screw",
	"Desc_Medkit_C": "Medicinal Inhaler",
	"Desc_ModularFrameFused_C": "Fused Modular Frame",
	"Desc_ModularFrameHeavy_C": "Heavy Modular Frame",
	"Desc_MotorLightweight_C": "Turbo Motor",
	"Desc_NobeliskCluster_C": "Cluster Nobelisk",
	"Desc_NobeliskExplosive_C": "Nobelisk",
	"Desc_NobeliskGas_C": "Gas Nobelisk",
	"Desc_NobeliskShockwave_C": "Pulse Nobelisk",
	"Desc_PackagedBiofuel_C": "Packaged Liquid Biofuel",
	"Desc_Rebar_Explosive_C": "Explosive Rebar",
	"Desc_Rebar_Spreadshot_C": "Shatter Rebar",
	"Desc_Rebar_Stunshot_C": "Stun Rebar",
	"Desc_SpikedRebar_C": "Iron Rebar",
	"Desc_SteelPlateReinforced_C": "Encased Industrial Beam",
	"Desc_SteelPlate_C": "Steel Beam",
	"Desc_TurboFuel_C": "Packaged Turbofuel",
]);

string L10n(string id) {
	if (ITEM_NAMES[id]) return ITEM_NAMES[id];
	sscanf(id, "Desc_%s_C", id);
	return String.trim(Regexp.SimpleRegexp("[A-Z][a-z]+")->replace(id) {return __ARGS__[0] + " ";});
}

void parse_savefile(string fn) {
	Stdio.Buffer data = Stdio.Buffer(Stdio.read_file(fn));
	data->read_only();
	//Huh. Unlike the vast majority of games out there, Satisfactory has info on its official wiki.
	//https://satisfactory.wiki.gg/wiki/Save_files
	//mapname is always "Persistent_Level"; sessname is what the user entered to describe the session.
	[int ver1, int ver2, int build, string mapname, string params, string sessname, int playtime] = data->sscanf("%-4c%-4c%-4c%-4H%-4H%-4H%-4c");
	if (ver1 < 13) return; //There seem to be some differences with really really old savefiles
	write("%s: %s\n", fn, sessname[..<1]);
	//visibility is "private", "friends only", etc. Not sure what the byte values are.
	//I've no idea what the session ID is at this point but it seems to stay constant for one session. It's always 22 bytes (plus the null).
	[int timestamp, int visibility, int objver, string modmeta, int modflags, string sessid] = data->sscanf("%-8c%c%-4c%-4H%-4c%-4H");
	data->read(24); //A bunch of uninteresting numbers. Possibly includes an RNG seed?
	[int cheats] = data->sscanf("%-4c"); //?? Whether AGSes are used?
	//The rest of the file is a series of compressed chunks. Each blob of deflated data has a
	//header prepended which is 49 bytes long.
	string decomp = "";
	while (sizeof(data)) {
		//Chunk header is a fixed eight byte string
		//Oddly, the inflated size is always 131072, even on the last chunk, which has whatever's left.
		//A lot of this is guesses, esp since most of this seems to be fixed format (eg type is always 3,
		//but I'm guessing that's a one-byte marker saying "gzipped"). In the last 24 bytes, there seem
		//to be more copies of the same information, no idea why.
		//werror("%O\n", ((string)data)[..20]);
		[string chunkhdr, int inflsz, int zero1, int type, int deflsz, int zero2, string unk9] = data->sscanf("%8s%-4c%-4c%c%-4c%-4c%24s");
		//????? For some reason, Pike segfaults if we don't first probe the buffer like this.
		//So don't remove this 'raw =' line even if raw itself isn't needed.
		string raw = (string)data;
		object gz = Gz.inflate();
		decomp += gz->inflate((string)data);
		data = Stdio.Buffer(gz->end_of_stream()); data->read_only();
	}
	//Alright. Now that we've unpacked all the REAL data, let's get to parsing.
	//Stdio.write_file("dump", decomp); Process.create_process(({"hd", "dump"}), (["stdout": Stdio.File("dump.hex", "wct")]));
	data = Stdio.Buffer(decomp); data->read_only();
	[int sz] = data->sscanf("%-8c"); //Total size (will be equal to sizeof(data) after this returns)
	//Most of these are fixed and have unknown purpose
	[int unk10, string unk11, int zero3, int unk12, int unk13, string unk14, int unk15] = data->sscanf("%-4c%-4H%-4c%-4c%-4c%-4H%-4c");
	for (int i = 0; i < 5; ++i) {
		[string title, int unk17, int unk18, int n] = data->sscanf("%-4H%-4c%-4c%-4c");
		//write("Next section: %d %O (%x/%x)\n", n, title, unk17, unk18);
		while (n--) {
			[string unk19, int unk20] = data->sscanf("%-4H%-4c");
		}
	}
	[int sublevelcount] = data->sscanf("%-4c");
	//write("Sublevels: %d\n", sublevelcount);
	multiset seen = (<>);
	mapping total_loot = ([]);
	array crashsites = ({ }), loot = ({ });
	while (sublevelcount-- > -1) {
		int pos = sizeof(decomp) - sizeof(data);
		//The persistent level (one past the sublevel count) has no name field.
		[string lvlname, int sz, int count] = data->sscanf(sublevelcount < 0 ? "%0s%-8c%-4c" : "%-4H%-8c%-4c");
		int endpoint = sizeof(data) + 4 - sz; //The size includes the count, so adjust our position accordingly
		//write("[%X] Level %O size %d count %d\n", pos, lvlname, sz, count);
		array objects = ({});
		while (count--) {
			//objtype, class, level, prop
			array obj = data->sscanf("%-4c%-4H%-4H%-4H");
			if (obj[0]) {
				//Actor
				obj += data->sscanf("%-4c%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4F%-4c"); //Transform (rotation/translation/scale)
			} else {
				//Object/component
				obj += data->sscanf("%-4H");
			}
			objects += ({obj});
		}
		[int coll] = data->sscanf("%-4c");
		while (coll--) {
			[string lvl, string path] = data->sscanf("%-4H%-4H");
			//write("Collectable: %O\n", path);
		}
		//Not sure what extra bytes there might be. Also, what if we're already past this point?
		if (sizeof(data) > endpoint) data->read(sizeof(data) - endpoint);
		[int entsz, int nument] = data->sscanf("%-8c%-4c");
		endpoint = sizeof(data) + 4 - entsz;
		//Note that nument ought to be the same as the object count (and therefore sizeof(objects)) from above
		for (int i = 0; i < sizeof(objects) && i < nument; ++i) {
			[int ver, int flg, int sz] = data->sscanf("%-4c%-4c%-4c");
			int propend = sizeof(data) - sz;
			if (objects[i][1] == "/Game/FactoryGame/World/Benefit/DropPod/BP_DropPod.BP_DropPod_C\0")
				crashsites += ({({(objects[i][3] / ".")[-1], objects[i][9..11]})});
			int interesting = 0;//has_value(objects[i][3], "BP_DropPod14_389"); //Should require 5 modular frames, can't see it though
			if (interesting) write("INTERESTING: %O\n", objects[i]);
			//if (!seen[objects[i][1]]) {write("OBJECT %O\n", objects[i][1]); seen[objects[i][1]] = 1;}
			if (objects[i][0]) {
				//Actor
				[string parlvl, string parpath, int components] = data->sscanf("%-4H%-4H%-4c");
				while (components--) {
					[string complvl, string comppath] = data->sscanf("%-4H%-4H");
					if (interesting) write("Component %O %O\n", complvl, comppath);
				}
			} else {
				//Object. Nothing interesting here.
			}
			//Properties.
			mapping parse_properties(int end) {
				mapping ret = ([]);
				//write("RAW PROPERTIES %O\n", ((string)data)[..sizeof(data) - end - 1]);
				while (sizeof(data) > end) {
					[string prop] = data->sscanf("%-4H");
					if (prop == "None\0") break; //There MAY still be a type after that, but it won't be relevant. If there is, it'll be skipped in the END part.
					[string type] = data->sscanf("%-4H");
					if (interesting) write("Prop %O %O\n", prop, type);
					[int sz, int idx] = data->sscanf("%-4c%-4c");
					if (type == "BoolProperty\0") {
						//Special-case: Doesn't have a type string, has the value in there instead
						[ret[prop], int zero] = data->sscanf("%c%c");
					} else if ((<"ArrayProperty\0", "ByteProperty\0", "EnumProperty\0", "SetProperty\0">)[type]) {
						//Complex types have a single type
						[string type, int zero] = data->sscanf("%-4H%c");
					} else if (type == "MapProperty\0") {
						//Mapping types have two types (key and value)
						[string keytype, string valtype, int zero] = data->sscanf("%-4H%-4H%c");
					} else if (type == "StructProperty\0") {
						//Struct types have more padding
						[string type, int zero] = data->sscanf("%-4H%17c");
						if (interesting) write("Type %O\n", type);
						switch (type) {
							case "InventoryStack\0": {
								//The stack itself is a property list. But a StructProperty inside it has less padding??
								int end = sizeof(data) - sz;
								//write("RAW INVENTORY %O\n", ((string)data)[..sizeof(data) - end - 1]);
								ret[prop] = parse_properties(end);
								sz = sizeof(data) - end; //Should now be zero
								break;
							}
							case "InventoryItem\0": {
								int end = sizeof(data) - sz;
								[int padding, ret[prop], int unk] = data->sscanf("%-4c%-4H%-4c");
								sz = sizeof(data) - end; //Should be zero
							}
							default: break;
						}
					} else if (type == "IntProperty\0") {
						//Primitive. Also potentially more interesting.
						[int zero, ret[prop]] = data->sscanf("%c%-4c");
						sz -= 4;
					} else if (type == "FloatProperty\0") {
						//Primitive. Also potentially more interesting.
						[int zero, ret[prop]] = data->sscanf("%c%-4F");
						sz -= 4;
					} else {
						//Primitive types have no type notation
						[int zero] = data->sscanf("%c");
					}
					if (sz) data->read(sz);
				}
				if (sizeof(data) > end) {
					string rest = data->read(sizeof(data) - end);
					//if (rest != "\0" * sizeof(rest)) write("REST %O\n", rest);
				}
				return ret;
			}
			mapping prop = parse_properties(propend);
			if (interesting) write("Properties %O\n", prop);
			if (has_value(objects[i][1], "Pickup_Spawnable")) {
				string id = (replace(prop["mPickupItems\0"][?"Item\0"] || "", "\0", "") / ".")[-1];
				int num = prop["mPickupItems\0"][?"NumItems\0"];
				total_loot[id] += num;
				loot += ({({id, num, objects[i][9..11]})});
				//write("Spawnable: (%.0f,%.0f,%.0f) %d of %s\n", objects[i][9], objects[i][10], objects[i][11], num, id);
			}
		}
		if (sizeof(data) > endpoint) data->read(sizeof(data) - endpoint);
		[int collected] = data->sscanf("%-4c");
		while (collected--) {
			[string lvl, string path] = data->sscanf("%-4H%-4H");
			//write("Collected %O\n", path);
		}
	}
	mapping crash_loot = ([]);
	foreach (loot, [string item, int num, array(float) pos]) {
		string closest; float distance;
		foreach (crashsites, [string crash, array(float) ref]) {
			float dist = `+(@((ref[*] - pos[*])[*] ** 2));
			//There are some loot items that are not actually near crash sites.
			//The furthest distance-squared I've seen of any crash site loot is two where
			//the drop pod is a little bit away from the centroid of the loot (DropPod7_5615
			//and DropPod3_12), and they still come in at less than 100,000,000 distance-squared
			//(10,000 diagonal distance from drop pod to loot item).
			if (dist > 1e8) continue;
			if (!closest || dist < distance) {closest = crash; distance = dist;}
		}
		crash_loot[closest] += ({({item, num, distance})});
	}
	foreach (crashsites, [string crash, array(float) pos]) {
		write("Crash site %s (%.0f,%.0f,%.0f)\n", crash - "\0", @pos);
		if (!crash_loot[crash]) write("\tNO LOOT HERE\n");
		else foreach (crash_loot[crash], [string item, int num, float dist])
			write("\t%d %s\n", num, item - "\0");
	}
	if (crash_loot[0]) {
		write("Loot not at a crash site:\n");
		foreach (crash_loot[0], [string item, int num, float dist]) {
			write("\t%d %s\n", num, item - "\0");
			total_loot[item] -= num; //Optionally exclude these from the total loot, thus making it "crash site loot" exclusively
		}
	}
	array items = indices(total_loot), counts = values(total_loot);
	sort(-counts[*], items, counts);
	write("Total loot:\n");
	foreach (counts; int i; int n) if (n) write("\t%d %s\n", n, L10n(items[i]));
	//Or format it for the wiki:
	//foreach (counts; int i; int n) if (n) write("* {{itemLink|%s}} (%d)\n", L10n(items[i]), n);
	write("Sighted crash sites: %d/118\n", sizeof(crashsites));
	foreach (sort((array)HARD_DRIVE_REQUIREMENTS), [string item, int qty]) {
		if (!total_loot[item]) write("Need %d %s\n", qty, L10n(item));
		else if (total_loot[item] < qty) write("Need %d more %s\n", qty - total_loot[item], L10n(item));
	}
	//The wiki says there's a 32-bit zero before this count, but I don't see it.
	//It's also possible that this refcnt isn't even here. Presumably no refs??
	if (sizeof(data)) {
		[int refcnt] = data->sscanf("%-4c");
		while (refcnt--) data->sscanf("%-4H%-4H");
	}
	if (sizeof(data)) write("[%X] Remaining: %d %O\n\n", sizeof(decomp) - sizeof(data), sizeof(data), data->read(128));
}

int main(int argc, array(string) argv) {
	if (argc < 2) exit(0, "Need a file to parse.\n");
	if (has_value(argv, "--latest")) {
		array files = argv[1..] - ({"--latest"});
		array dates = file_stat(files[*])->mtime;
		sort(dates, files);
		parse_savefile(files[-1]);
		return 0;
	}
	parse_savefile(argv[1..][*]);
}
