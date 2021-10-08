import choc, {set_content, DOM, on, fix_dialogs} from "https://rosuav.github.io/shed/chocfactory.js";
const {A, BR, CODE, LABEL, LI, TABLE, TR, TD, INPUT, SELECT, OPTION, OPTGROUP, SPAN} = choc;
fix_dialogs({close_selector: ".dialog_cancel,.dialog_close", click_outside: "formless"});
//TODO: Check styles, esp colours, on GH Pages
//TODO: Categorize resources. Iron/Copper/Steel? Group by tier? Industrial/Electronic?
//TODO: Verify all resource IDs

/* In order to round-trip with Nogg's ContentLib recipe format, still need:
- A way to reorder a refinery's inputs and outputs (separate flags for "fluid first"?)
*/

/* On sink values and fluids

Almost all of the core recipes give products with precisely double the sink value of their
inputs. This appears to be how sink values are calculated in the first place. For example,
iron ore has a sink value of 1, and can be smelted into iron ingots with a sink value of 2,
and a single ingot can be turned into one iron rod with a sink value of 4, or three of them
can be turned into a pair of plates for six each (3 ingots * 2 each ==> 2 plates * 6 each).

Recipes obtained via hard drives can therefore be evaluated for resource efficiency on this
basis. Iron Wire is incredibly resource efficient, but Caterium Wire is not; this balances
the fact that Iron Wire is slower than the default copper recipe, but Caterium Wire is
significantly faster. So far, so good.

Fluids do not directly have sink values. You cannot pour crude oil down the sink, which is
probably a good thing :) But it complicates recipe analysis.

Core recipes that involve only a single fluid:
* Fused Modular Frame
* Petroleum Coke
* Residual Plastic/Rubber if you don't treat them as alternates

Based on the Petroleum Coke recipe, it seems logical for Heavy Oil Residue to have a sink
value of 30. This would then imply that packaging it takes two Residue (30+30), two Empty
Canisters (60+60), and produces two Packaged Residue (180+180), for a perfect 2:1 ratio,
despite packaging being reversible. That seems plausible.

If that's the case, then the formula for fluid sink values would be half the packaged minus
sixty (ignoring GasTank recipes for now). That would mean:

Fluid     | Pkg | Liquid
----------|-----|---------
Water     | 130 | 5
Sulfuric  | 152 | 16
Alumina   | 160 | 20
Crude     | 160 | 20
Residue   | 180 | 30
Fuel      | 270 | 75
Biofuel   | 370 | 125
Turbofuel | 570 | 225

Reasonably plausible values. Unfortunately they still don't all work.

The basic Plastic and Rubber recipes give a 3:1 improvement, which seems plausible, given
that they pay a complexity price (you can't value the Residue as a resource when it's mainly
there to be a hassle); Residual Plastic is exactly 2:1, and Residual Rubber slightly better.
But more surprising is that Diluted Packaged Fuel now shows a mere 86% improvement, whereas
its Blender counterpart, Diluted Fuel, has a 3.75:1 improvement, despite being functionally
equivalent. That's a problem... or is it? Maybe it's just hard to compare packaged/unpackaged.

Perhaps water is the problem here: it is valued lower than other fluids are, and needs to be
rated artificially at, say. 1.5. But that still wouldn't make Sulfuric Acid work; five Sulfur
(11) plus five Water makes five Sulfuric Acid, and it's hard to make numbers that make sense
here. Sulfuric itself is never used in recipes with entirely-solid outputs, always yielding
some water, or in one case, some residual acid: ten Uranium (35) plus three Concrete (12)
pluis eight Sulfuric yields five Encased Cells (147) plus two Sulfuric. Whichever way you
look at it, that one doesn't come out to 2:1. Excluding the acid, it's 386 input to make
735 output; and that would imply that the acid has to have a *negative* value. Meanwhile, the
alternate "Infused Uranium Cell" recipe is 5*35+3*20+5*11+15*17 to yield 4*147, or 545 => 588.
So that's no help either.
*/

//TODO: Crib these from the files somehow so they don't have to be updated.
const machines = {
	constructor: {name: "Constructor", input: "s", output: "s", cost: 4, id: "ConstructorMk1"},
	smelter: {name: "Smelter", input: "s", output: "s", cost: 4, id: "SmelterMk1"},
	assembler: {name: "Assembler", input: "ss", output: "s", cost: 15, id: "AssemblerMk1"},
	foundry: {name: "Foundry", input: "ss", output: "s", cost: 16, id: "FoundryMk1"},
	refinery: {name: "Refinery", input: "sf", output: "sf", cost: 30, id: "OilRefinery"},
	manufacturer: {name: "Manufacturer", input: "ssss", output: "s", cost: 30, id: "ManufacturerMk1"},
	blender: {name: "Blender", input: "ssff", output: "sf", cost: 75, id: "Blender"},
	//Particle Accelerator id: "HadronCollider"?
};
const par = DOM("input[name=manual]").closest("ul");
Object.keys(machines).forEach(m => par.appendChild(LI(LABEL([INPUT({type: "radio", name: "machine", value: m}), machines[m].name]))));
//NOTE: This list is not complete. It lacks nuclear power, project parts, and most things that don't have sink values.
const solid_resources = {
	None: {sink: 0, name: "None"},
	OreIron: {sink: 1, name: "Iron Ore"},
	Stone: {sink: 2, name: "Limestone"},
	IronIngot: {sink: 2, name: "Iron Ingot"},
	IronScrew: {sink: 2, name: "Screw"},
	Coal: {sink: 3, energy: 300, name: "Coal"},
	Leaves: {sink: 3, energy: 15, name: "Leaves"},
	OreCopper: {sink: 3, name: "Copper Ore"},
	IronRod: {sink: 4, name: "Iron Rod"},
	IronPlate: {sink: 6, name: "Iron Plate"},
	CopperIngot: {sink: 6, name: "Copper Ingot"},
	Wire: {sink: 6, name: "Wire"},
	OreGold: {sink: 7, name: "Caterium Ore"},
	SteelIngot: {sink: 8, name: "Steel Ingot"},
	OreBauxite: {sink: 8, name: "Bauxite"},
	FlowerPetals: {sink: 10, energy: 100, name: "Flower Petals"},
	Mycelia: {sink: 10, energy: 20, name: "Mycelia"},
	Sulfur: {sink: 11, name: "Sulfur"},
	PolymerResin: {sink: 12, name: "Polymer Resin"},
	GenericBiomass: {sink: 12, energy: 180, name: "Biomass"},
	Cement: {sink: 12, name: "Concrete"},
	RawQuartz: {sink: 15, name: "Raw Quartz"},
	HighSpeedWire: {sink: 17, name: "Quickwire"},
	PetroleumCoke: {sink: 20, energy: 180, name: "Petroleum Coke"},
	Silica: {sink: 20, name: "Silica"},
	SteelPipe: {sink: 24, name: "Steel Pipe"},
	Cable: {sink: 24, name: "Cable"},
	CopperSheet: {sink: 24, name: "Copper Sheet"},
	AluminumScrap: {sink: 27, name: "Aluminum Scrap"},
	CompactedCoal: {sink: 28, energy: 630, name: "Compacted Coal"},
	Wood: {sink: 30, energy: 100, name: "Wood"},
	OreUranium: {sink: 35, name: "Uranium"},
	GoldIngot: {sink: 42, name: "Caterium Ingot"},
	Biofuel: {sink: 48, energy: 450, name: "Solid Biofuel"},
	Gunpowder: {sink: 50, name: "Black Powder"},
	QuartzCrystal: {sink: 50, name: "Quartz Crystal"},
	FluidCanister: {sink: 60, name: "Empty Canister"},
	Rubber: {sink: 60, name: "Rubber"},
	SteelPlate: {sink: 64, name: "Steel Beam"},
	Plastic: {sink: 75, name: "Plastic"},
	IronPlateReinforced: {sink: 120, name: "Reinforced Iron Plate"},
	PackagedWater: {sink: 130, name: "Packaged Water"},
	AluminumIngot: {sink: 131, name: "Aluminum Ingot"},
	Rotor: {sink: 140, name: "Rotor"},
	PackagedSulfuricAcid: {sink: 152, name: "Packaged Sulfuric Acid"},
	PackagedAlumina: {sink: 160, name: "Packaged Alumina Solution", unpackaged: "AluminaSolution"},
	PackagedOil: {sink: 160, energy: 320, name: "Packaged Oil", unpackaged: "CrudeOil", unpkgname: "Crude Oil"},
	PackagedOilResidue: {sink: 180, energy: 400, name: "Packaged Heavy Oil Residue", unpackaged: "HeavyOilResidue"},
	GasTank: {sink: 225, name: "Empty Fluid Tank"},
	Stator: {sink: 240, name: "Stator"},
	AluminumPlate: {sink: 266, name: "Alclad Aluminum Sheet"},
	Fuel: {sink: 270, energy: 750, name: "Packaged Fuel", unpackaged: "LiquidFuel"},
	PackagedNitrogenGas: {sink: 312, name: "Packaged Nitrogen Gas", pkg: "GasTank"},
	EquipmentDescriptorBeacon: {sink: 320, name: "Beacon"},
	PackagedBiofuel: {sink: 370, energy: 750, name: "Packaged Liquid Biofuel", unpackaged: "LiquidBiofuel"},
	AluminumCasing: {sink: 393, name: "Aluminum Casing"},
	ModularFrame: {sink: 408, name: "Modular Frame"},
	PackagedNitricAcid: {sink: 412, name: "Packaged Nitric Acid", pkg: "GasTank", unpackaged: "UnpackageNitricAcid"}, //TODO: Check the unpackaged name
	Battery: {sink: 465, energy: 6000, name: "Battery"},
	TurboFuel: {sink: 570, energy: 2000, name: "Packaged Turbofuel", unpackaged: "LiquidTurboFuel"},
	SteelPlateReinforced: {sink: 632, name: "Encased Industrial Beam"},
	CircuitBoard: {sink: 696, name: "Circuit Board"},
	CircuitBoardHighSpeed: {sink: 920, name: "AI Limiter"},
	Motor: {sink: 1520, name: "Motor"},
	ElectromagneticControlRod: {sink: 2560, name: "Electromagnetic Control Rod"},
	AluminumPlateReinforced: {sink: 2804, name: "Heat Sink"},
	CrystalOscillator: {sink: 3072, name: "Crystal Oscillator"},
	HighSpeedConnector: {sink: 3776, name: "High-Speed Connector"},
	ModularFrameHeavy: {sink: 11520, name: "Heavy Modular Frame"},
	CoolingSystem: {sink: 12006, name: "Cooling System"},
	Computer: {sink: 17260, name: "Computer"},
	ModularFrameLightweight: {sink: 32908, name: "Radio Control Unit"},
	ModularFrameFused: {sink: 62840, name: "Fused Modular Frame"},
	ComputerSuper: {sink: 99576, name: "Supercomputer"},
	MotorLightweight: {sink: 242720, name: "Turbo Motor"},
	PressureConversionCube: {sink: 257312, name: "Pressure Conversion Cube"},
	HogParts: {sink: 0, energy: 250, name: "Alien Carapace"},
	SpitterParts: {sink: 0, energy: 250, name: "Alien Organs"},
};
//Sink values of fluids are defined by their packaged equivalents, minus 60 for
//the package itself. This completely discounts any processing value from the
//package/unpackage process, since it's reversible.
const fluid_resources = {None: solid_resources.None};
const resources = {...solid_resources};
for (let id in solid_resources) {
	const r = solid_resources[id];
	if (id.startsWith("Packaged") || r.unpackaged) {
		id = r.unpackaged || id.replace("Packaged", "");
		resources[id] = fluid_resources[id] = {
			...r,
			sink: r.unpkgsink || (r.sink - solid_resources[r.pkg || "FluidCanister"].sink),
			name: r.unpkgname || r.name.replace("Packaged ", ""),
		};
	}
}
const resource_ids = {
	s: Object.keys(solid_resources),
	f: Object.keys(fluid_resources),
	a: Object.keys(resources),
};

//I apologize to anyone in the future who has to look at this code. :(
function group_research(map) {
	const groups = { };
	Object.entries(map).map(([kwd, desc]) => {
		let grp = /^[A-Za-z]*/.exec(kwd)[0];
		if (grp === "") return;
		//Alien Organisms is broken up internally but a single tree to the player
		if (grp === "ACarapace" || grp === "AOrgans" || grp === "AOrganisms") grp = "AlienOrganisms";
		if (!groups[grp]) groups[grp] = [];
		groups[grp].push(OPTION({value: "Research_" + kwd}, desc));
	});
	return Object.entries(groups).map(([kwd, items]) => OPTGROUP({label: kwd.replace(/([^A-Z])([A-Z])/g, "$1 $2")}, items));
}

set_content("#unlock", [
	OPTGROUP({label: "Tutorial"}, "1 1_5 2 3 4 5".split(" ").map((id, i) => OPTION({value: "Schematic_Tutorial_" + id}, "HUB Upgrade " + (i + 1)))),
	...[
		["Base Building", "Logistics", "Field Research"],
		["Part Assembly", "Obstacle Clearing", "Jump Pads", "Resource Sink Bonus Program", "Logistics Mk.2"],
		["Coal Power", "Vehicular Transport", "Basic Steel Production"],
		["Advanced Steel Production", "Improved Melee Combat", "Hyper Tubes", "Logistics Mk.3"],
		["Oil Processing", "Industrial Manufacturing", "Alternative Fluid Transport", "Gas Mask"],
		["Expanded Power Infrastructure", "Jetpack", "Monorail Train Technology", "Pipeline Engineering Mk.2"],
		["Bauxite Refinement", "Logistics Mk.5", "Aeronautical Engineering", "Hazmat Suit", "Hover Pack"],
		["Nuclear Power", "Advanced Aluminum Production", "Leading-edge Production", "Particle Enrichment"],
	].map((milestones, idx) => OPTGROUP({label: "Tier " + (idx+1)},
		milestones.map((desc, i) => OPTION({value: "Schematic_" + (idx+1) + "-" + (i+1)}, desc))
	)),
	...group_research(
		//https://satisfactory-calculator.com/en/mam
		//console.log(JSON.stringify((() => {const opts = {}; document.querySelectorAll('a[href*="/en/mam/detail"]:not([href*=XMas]) strong').forEach(el => opts[/Research_(.*?)_C/.exec(el.closest("a").href)[1]] = el.innerText); return opts;})()))
		{"ACarapace_0":"Alien Carapace","ACarapace_1":"Structural Analysis","ACarapace_2_1":"Spiked Rebars","ACarapace_2":"Rebar Gun","ACarapace_3":"Expanded Toolbelt","AOrganisms_1":"Object Scanner Improvements","AOrganisms_2":"Hostile Organism Detection","AOrgans_0":"Alien Organs","AOrgans_1":"Organic Properties","AOrgans_2":"Medicinal Inhaler","AOrgans_3":"Inflated Pocket Dimension","Caterium_0":"Caterium","Caterium_1":"Caterium Ingots","Caterium_2_1":"Zipline","Caterium_2":"Quickwire","Caterium_3_1":"Inflated Pocket Dimension","Caterium_3":"Caterium Electronics","Caterium_4_1_1":"Smart Splitter","Caterium_4_1_2":"Power Switch","Caterium_4_1":"AI Limiter","Caterium_4_2":"Power Poles Mk.2","Caterium_4_3":"Blade Runners","Caterium_5":"High-Speed Connector","Caterium_6_1":"Supercomputer","Caterium_6_2":"Power Poles Mk.3","Caterium_6_3":"Inflated Pocket Dimension","Caterium_7_1":"Programmable Splitter","Caterium_7_2":"Geothermal Generator","FlowerPetals_1":"Flower Petals","FlowerPetals_2":"Color Gun","FlowerPetals_3":"Color Cartridges","Mycelia_1":"Mycelia","Mycelia_2":"Fabric","Mycelia_3":"Parachute","Mycelia_4":"Medical Properties","Mycelia_5":"Medicinal Inhaler","Nutrients_0":"Paleberry","Nutrients_1":"Beryl Nut","Nutrients_2":"Bacon Agaric","Nutrients_3":"Nutritional Mixture","Nutrients_4":"Nutritional Inhaler","PowerSlugs_1":"Green Power Slugs","PowerSlugs_2":"Overclock Production","PowerSlugs_3":"Slug Scanning","PowerSlugs_4":"Yellow Power Shards","PowerSlugs_5":"Purple Power Shards","Quartz_0":"Quartz","Quartz_1_1":"Quartz Crystals","Quartz_1_2":"Silica","Quartz_2":"Crystal Oscillator","Quartz_3_1":"The Explorer","Quartz_3_2":"Frequency Mapping","Quartz_3_3":"Radio Control Unit","Quartz_3":"Signal Technologies","Quartz_4_1":"Radio Signal Scanning","Quartz_4":"Radar Technology","Sulfur_0":"Sulfur","Sulfur_1":"Black Powder","Sulfur_2":"Volatile Applications","Sulfur_3_1":"Nobelisk Detonator","Sulfur_3_2_1":"Nobelisk Explosives","Sulfur_4_1":"The Rifle","Sulfur_4_2_1":"Rifle Cartridges","Sulfur_5":"Expanded Toolbelt","Sulfur_6":"Inflated Pocket Dimension"}
	),
]);

//Recipe order doesn't matter much as the display is usually sorted by something more relevant.
const recipes = [
	{machine: "constructor", time: 2, input: {AluminumIngot: 3}, output: {AluminumCasing: 2}},
	{machine: "constructor", time: 2, input: {GenericBiomass: 5}, output: {Coal: 6}, name: "Biocoal"},
	{machine: "constructor", time: 4, input: {HogParts: 1}, output: {GenericBiomass: 100}, name: "Biomass (Alien Carapace)"},
	{machine: "constructor", time: 8, input: {SpitterParts: 1}, output: {GenericBiomass: 200}, name: "Biomass (Alien Organs)"},
	{machine: "constructor", time: 5, input: {Leaves: 10}, output: {GenericBiomass: 5}, name: "Biomass (Leaves)"},
	{machine: "constructor", time: 4, input: {Mycelia: 10}, output: {GenericBiomass: 10}, name: "Biomass (Mycelia)"},
	{machine: "constructor", time: 4, input: {Wood: 4}, output: {GenericBiomass: 20}, name: "Biomass (Wood)"},
	{machine: "constructor", time: 2, input: {Wire: 2}, output: {Cable: 1}},
	{machine: "constructor", time:24, input: {IronIngot: 5}, output: {IronScrew: 20}, name: "Cast Screw"},
	{machine: "constructor", time: 4, input: {GoldIngot: 1}, output: {Wire: 8}, name: "Caterium Wire"},
	{machine: "constructor", time: 4, input: {Wood: 1}, output: {Coal: 10}, name: "Charcoal"},
	{machine: "constructor", time: 4, input: {Stone: 3}, output: {Cement: 1}},
	{machine: "constructor", time: 6, input: {CopperIngot: 2}, output: {CopperSheet: 1}},
	{machine: "constructor", time: 4, input: {Plastic: 2}, output: {FluidCanister: 4}},
	{machine: "constructor", time: 1, input: {AluminumIngot: 2}, output: {GasTank: 1}},
	{machine: "constructor", time: 6, input: {IronIngot: 3}, output: {IronPlate: 2}},
	{machine: "constructor", time: 4, input: {IronIngot: 1}, output: {IronRod: 1}},
	{machine: "constructor", time:24, input: {IronIngot: 5}, output: {Wire: 9}, name: "Iron Wire"},
	{machine: "constructor", time: 8, input: {RawQuartz: 5}, output: {QuartzCrystal: 3}},
	{machine: "constructor", time: 5, input: {GoldIngot: 1}, output: {HighSpeedWire: 5}},
	{machine: "constructor", time: 6, input: {RawQuartz: 3}, output: {Silica: 5}},
	{machine: "constructor", time: 4, input: {GenericBiomass: 8}, output: {Biofuel: 4}},
	{machine: "constructor", time: 4, input: {SteelIngot: 4}, output: {SteelPlate: 1}},
	{machine: "constructor", time: 3, input: {SteelIngot: 3}, output: {FluidCanister: 2}, name: "Steel Canister"},
	{machine: "constructor", time: 6, input: {SteelIngot: 3}, output: {SteelPipe: 2}},
	{machine: "constructor", time: 5, input: {SteelIngot: 1}, output: {IronRod: 4}, name: "Steel Rod"},
	{machine: "constructor", time:12, input: {SteelIngot: 1}, output: {IronScrew: 52}, name: "Steel Screw"},
	{machine: "constructor", time: 4, input: {CopperIngot: 1}, output: {Wire: 2}},

	{machine: "smelter", time: 2, input: {OreIron: 1}, output: {IronIngot: 1}},
	{machine: "smelter", time: 2, input: {OreCopper: 1}, output: {CopperIngot: 1}},
	{machine: "smelter", time: 4, input: {OreGold: 3}, output: {GoldIngot: 1}},
	{machine: "smelter", time: 2, input: {AluminumScrap: 2}, output: {AluminumIngot: 1}, name: "Pure Aluminum Ingot"},

	{machine: "assembler", time: 16, input: {IronPlate: 3, Rubber: 1}, output: {IronPlateReinforced: 1}, name: "Adhered Iron Plate"},
	{machine: "assembler", time: 12, input: {CopperSheet: 5, HighSpeedWire: 20}, output: {CircuitBoardHighSpeed: 1}},
	{machine: "assembler", time:  6, input: {AluminumIngot: 3, CopperIngot: 1}, output: {AluminumPlate: 3}},
	{machine: "assembler", time:  8, input: {AluminumIngot: 20, CopperIngot: 10}, output: {AluminumCasing: 15}, name: "Alclad Casing"},
	{machine: "assembler", time:  8, input: {Coal: 1, Sulfur: 2}, output: {Gunpowder: 1}},
	{machine: "assembler", time: 24, input: {IronPlateReinforced: 3, IronScrew: 56}, output: {ModularFrame: 2}, name: "Bolted Frame"},
	{machine: "assembler", time: 12, input: {IronPlate: 18, IronScrew: 50}, output: {IronPlateReinforced: 3}, name: "Bolted Iron Plate"},
	{machine: "assembler", time: 48, input: {Plastic: 10, HighSpeedWire: 30}, output: {CircuitBoard: 7}, name: "Caterium Circuit Board"},
	{machine: "assembler", time: 16, input: {RawQuartz: 3, Stone: 5}, output: {Silica: 7}, name: "Cheap Silica"},
	{machine: "assembler", time:  8, input: {CopperSheet: 2, Plastic: 4}, output: {CircuitBoard: 1}},
	{machine: "assembler", time: 12, input: {IronIngot: 10, Plastic: 2}, output: {IronPlate: 15}, name: "Coated Iron Plate"},
	{machine: "assembler", time: 12, input: {Coal: 5, Sulfur: 5}, output: {CompactedCoal: 5}},
	{machine: "assembler", time: 16, input: {CopperSheet: 6, IronScrew: 52}, output: {Rotor: 3}, name: "Copper Rotor"},
	{machine: "assembler", time: 64, input: {CircuitBoard: 8, CrystalOscillator: 3}, output: {Computer: 3}, name: "Crystal Computer"},
	{machine: "assembler", time: 16, input: {ElectromagneticControlRod: 1, Rotor: 2}, output: {Motor: 2}, name: "Electric Motor"},
	{machine: "assembler", time: 12, input: {Rubber: 6, PetroleumCoke: 9}, output: {CircuitBoard: 1}, name: "Electrode Circuit Board"},
	{machine: "assembler", time: 15, input: {Stator: 2, HighSpeedConnector: 1}, output: {ElectromagneticControlRod: 2}, name: "Electromagnetic Connection Rod"},
	{machine: "assembler", time: 30, input: {Stator: 2, CircuitBoardHighSpeed: 2}, output: {ElectromagneticControlRod: 2}},
	{machine: "assembler", time: 10, input: {SteelPlate: 4, Cement: 5}, output: {SteelPlateReinforced: 1}},
	{machine: "assembler", time: 15, input: {SteelPipe: 7, Cement: 5}, output: {SteelPlateReinforced: 1}, name: "Encased Industrial Pipe"},
	{machine: "assembler", time: 16, input: {Sulfur: 2, CompactedCoal: 1}, output: {Gunpowder: 4}, name: "Fine Black Powder"},
	{machine: "assembler", time: 24, input: {Silica: 3, Stone: 12}, output: {Cement: 10}, name: "Fine Concrete"},
	{machine: "assembler", time:  8, input: {GoldIngot: 1, CopperIngot: 5}, output: {HighSpeedWire: 12}, name: "Fused Quickwire"},
	{machine: "assembler", time: 20, input: {CopperIngot: 4, GoldIngot: 1}, output: {Wire: 30}, name: "Fused Wire"},
	{machine: "assembler", time:  6, input: {AluminumCasing: 3, Rubber: 3}, output: {AluminumPlateReinforced: 1}, name: "Heat Exchanger"},
	{machine: "assembler", time:  8, input: {AluminumPlate: 5, CopperSheet: 3}, output: {AluminumPlateReinforced: 1}},
	{machine: "assembler", time: 12, input: {Wire: 9, Rubber: 6}, output: {Cable: 20}, name: "Insulated Cable"},
	{machine: "assembler", time: 60, input: {IronPlateReinforced: 3, IronRod: 12}, output: {ModularFrame: 2}},
	{machine: "assembler", time: 12, input: {Rotor: 2, Stator: 2}, output: {Motor: 1}},
	{machine: "assembler", time: 20, input: {ModularFrameLightweight: 3, CoolingSystem: 3}, output: {ComputerSuper: 1}, name: "OC Supercomputer"},
	{machine: "assembler", time: 60, input: {ModularFrameFused: 1, ModularFrameLightweight: 2}, output: {PressureConversionCube: 1}},
	{machine: "assembler", time: 24, input: {HighSpeedWire: 3, Rubber: 2}, output: {Cable: 11}, name: "Quickwire Cable"},
	{machine: "assembler", time: 15, input: {SteelPipe: 4, HighSpeedWire: 15}, output: {Stator: 2}, name: "Quickwire Stator"},
	{machine: "assembler", time: 12, input: {IronPlate: 6, IronScrew: 12}, output: {IronPlateReinforced: 1}},
	{machine: "assembler", time: 15, input: {IronRod: 5, IronScrew: 25}, output: {Rotor: 1}},
	{machine: "assembler", time: 12, input: {Stone: 10, Rubber: 2}, output: {Cement: 9}, name: "Rubber Concrete"},
	{machine: "assembler", time: 24, input: {CopperSheet: 11, Silica: 11}, output: {CircuitBoard: 5}, name: "Silicon Circuit Board"},
	{machine: "assembler", time: 12, input: {SteelPipe: 3, Wire: 8}, output: {Stator: 1}},
	{machine: "assembler", time: 24, input: {SteelIngot: 3, Plastic: 2}, output: {IronPlate: 18}, name: "Steel Coated Plate"},
	{machine: "assembler", time: 12, input: {SteelPipe: 2, Wire: 6}, output: {Rotor: 1}, name: "Steel Rotor"},
	{machine: "assembler", time: 60, input: {IronPlateReinforced: 2, SteelPipe: 10}, output: {ModularFrame: 3}, name: "Steeled Frame"},
	{machine: "assembler", time: 32, input: {IronPlate: 10, Wire: 20}, output: {IronPlateReinforced: 3}, name: "Stitched Iron Plate"},

	{machine: "foundry", time: 4, input: {OreIron: 3, Coal: 3}, output: {SteelIngot: 3}},
	{machine: "foundry", time: 3, input: {IronIngot: 2, Coal: 2}, output: {SteelIngot: 3}, name: "Solid Steel Ingot"},
	{machine: "foundry", time: 12, input: {OreIron: 15, PetroleumCoke: 15}, output: {SteelIngot: 20}, name: "Coke Steel Ingot"},
	{machine: "foundry", time: 16, input: {OreIron: 6, CompactedCoal: 3}, output: {SteelIngot: 10}, name: "Compacted Steel Ingot"},
	{machine: "foundry", time: 12, input: {OreCopper: 10, OreIron: 5}, output: {CopperIngot: 20}, name: "Copper Alloy Ingot"},
	{machine: "foundry", time: 6, input: {OreIron: 2, OreCopper: 2}, output: {IronIngot: 5}, name: "Iron Alloy Ingot"},
	{machine: "foundry", time: 4, input: {AluminumScrap: 6, Silica: 5}, output: {AluminumIngot: 4}},

	{machine: "refinery", time: 6, input: {OreBauxite: 12, Water: 18}, output: {AluminaSolution: 12, Silica: 5}},
	{machine: "refinery", time: 1, input: {AluminaSolution: 4, Coal: 2}, output: {AluminumScrap: 6, Water: 2}},
	{machine: "refinery", time: 8, input: {Wire: 5, HeavyOilResidue: 2}, output: {Cable: 9}, name: "Coated Cable"},
	{machine: "refinery", time: 2, input: {HeavyOilResidue: 1, PackagedWater: 2}, output: {Fuel: 2}, name: "Diluted Packaged Fuel"},
	{machine: "refinery", time: 4, input: {AluminaSolution: 12, PetroleumCoke: 4}, output: {AluminumScrap: 20, Water: 7}, name: "Electrode - Aluminum Scrap"},
	{machine: "refinery", time: 6, input: {CrudeOil: 6}, output: {Fuel: 4, PolymerResin: 3}},
	{machine: "refinery", time: 6, input: {CrudeOil: 3}, output: {HeavyOilResidue: 4, PolymerResin: 2}},
	{machine: "refinery", time: 4, input: {Biofuel: 6, Water: 3}, output: {LiquidBiofuel: 4}},
	{machine: "refinery", time: 6, input: {HeavyOilResidue: 4}, output: {PetroleumCoke: 12}},
	{machine: "refinery", time: 6, input: {CrudeOil: 3}, output: {Plastic: 2, HeavyOilResidue: 1}},
	{machine: "refinery", time: 6, input: {CrudeOil: 6}, output: {PolymerResin: 13, HeavyOilResidue: 2}},
	{machine: "refinery", time: 5, input: {OreGold: 2, Water: 2}, output: {GoldIngot: 1}, name: "Pure Caterium Ingot"},
	{machine: "refinery", time:24, input: {OreCopper: 6, Water: 4}, output: {CopperIngot: 15}, name: "Pure Copper Ingot"},
	{machine: "refinery", time:12, input: {OreIron: 7, Water: 4}, output: {IronIngot: 13}, name: "Pure Iron Ingot"},
	{machine: "refinery", time: 8, input: {RawQuartz: 9, Water: 5}, output: {QuartzCrystal: 7}, name: "Pure Quartz Crystal"},
	{machine: "refinery", time:12, input: {Rubber: 6, LiquidFuel: 6}, output: {Plastic: 12}, name: "Recycled Plastic"},
	{machine: "refinery", time:12, input: {Plastic: 6, LiquidFuel: 6}, output: {Rubber: 12}, name: "Recycled Rubber"},
	{machine: "refinery", time: 6, input: {HeavyOilResidue: 6}, output: {LiquidFuel: 4}, name: "Residual Fuel"},
	{machine: "refinery", time: 6, input: {PolymerResin: 6, Water: 2}, output: {Plastic: 2}, name: "Residual Plastic"},
	{machine: "refinery", time: 6, input: {PolymerResin: 4, Water: 4}, output: {Rubber: 2}, name: "Residual Rubber"},
	{machine: "refinery", time: 6, input: {CrudeOil: 3}, output: {Rubber: 2, HeavyOilResidue: 2}},
	{machine: "refinery", time: 3, input: {OreBauxite: 10, Water: 10}, output: {AluminaSolution: 12}, name: "Sloppy Alumina"},
	{machine: "refinery", time: 8, input: {CopperIngot: 3, Water: 3}, output: {CopperSheet: 3}, name: "Steamed Copper Sheet"},
	{machine: "refinery", time: 6, input: {Sulfur: 5, Water: 5}, output: {SulfuricAcid: 5}},
	{machine: "refinery", time: 8, input: {HeavyOilResidue: 5, CompactedCoal: 4}, output: {TurboFuel: 4}, name: "Turbo Heavy Fuel"},
	{machine: "refinery", time:16, input: {Fuel: 6, CompactedCoal: 4}, output: {TurboFuel: 5}},
	{machine: "refinery", time: 3, input: {Stone: 6, Water: 5}, output: {Cement: 4}, name: "Wet Concrete"},

	{machine: "manufacturer", time:  8, output: {EquipmentDescriptorBeacon: 1},
		input: {IronPlate: 3, IronRod: 1, Wire: 16, Cable: 2}},
	{machine: "manufacturer", time: 16, output: {Computer: 1}, name: "Caterium Computer",
		input: {CircuitBoard: 7, HighSpeedWire: 28, Rubber: 12}},
	{machine: "manufacturer", time:  8, output: {Battery: 1}, name: "Classic Battery",
		input: {Sulfur: 6, AluminumPlate: 7, Plastic: 8, Wire: 12}},
	{machine: "manufacturer", time: 24, output: {Computer: 1},
		input: {CircuitBoard: 10, Cable: 9, Plastic: 18, IronScrew: 52}},
	{machine: "manufacturer", time:120, output: {EquipmentDescriptorBeacon: 20}, name: "Crystal Beacon",
		input: {SteelPlate: 4, SteelPipe: 16, CrystalOscillator: 1}},
	{machine: "manufacturer", time:120, output: {CrystalOscillator: 2},
		input: {QuartzCrystal: 36, Cable: 28, IronPlateReinforced: 5}},
	{machine: "manufacturer", time: 64, output: {ModularFrameHeavy: 3}, name: "Heavy Encased Frame",
		input: {ModularFrame: 8, SteelPlateReinforced: 10, SteelPipe: 36, Cement: 22}},
	{machine: "manufacturer", time: 16, output: {ModularFrameHeavy: 1}, name: "Heavy Flexible Frame",
		input: {ModularFrame: 5, SteelPlateReinforced: 3, Rubber: 20, IronScrew: 104}},
	{machine: "manufacturer", time: 30, output: {ModularFrameHeavy: 1},
		input: {ModularFrame: 5, SteelPipe: 15, SteelPlateReinforced: 5, IronScrew: 100}},
	{machine: "manufacturer", time: 16, output: {HighSpeedConnector: 1},
		input: {HighSpeedWire: 56, Cable: 10, CircuitBoard: 1}},
	{machine: "manufacturer", time: 32, output: {CrystalOscillator: 1}, name: "Insulated Crystal Oscillator",
		input: {QuartzCrystal: 10, Rubber: 7, CircuitBoardHighSpeed: 1}},
	{machine: "manufacturer", time: 16, output: {ModularFrameLightweight: 1}, name: "Radio Connection Unit",
		input: {AluminumPlateReinforced: 4, HighSpeedConnector: 2, QuartzCrystal: 12}},
	{machine: "manufacturer", time: 40, output: {ModularFrameLightweight: 3}, name: "Radio Control System",
		input: {CrystalOscillator: 1, CircuitBoard: 10, AluminumCasing: 60, Rubber: 30}},
	{machine: "manufacturer", time: 48, output: {ModularFrameLightweight: 2},
		input: {AluminumCasing: 32, CrystalOscillator: 1, Computer: 1}},
	{machine: "manufacturer", time: 48, output: {Motor: 6}, name: "Rigour Motor",
		input: {Rotor: 3, Stator: 3, CrystalOscillator: 1}},
	{machine: "manufacturer", time: 40, output: {HighSpeedConnector: 2}, name: "Silicon High-Speed Connector",
		input: {HighSpeedWire: 60, Silica: 25, CircuitBoard: 2}},
	{machine: "manufacturer", time: 50, output: {ComputerSuper: 2}, name: "Super-State Computer",
		input: {Computer: 3, ElectromagneticControlRod: 2, Battery: 20, Wire: 45}},
	{machine: "manufacturer", time: 32, output: {ComputerSuper: 1},
		input: {Computer: 2, CircuitBoardHighSpeed: 2, HighSpeedConnector: 3, Plastic: 28}},
	{machine: "manufacturer", time: 64, output: {MotorLightweight: 3}, name: "Turbo Electric Motor",
		input: {Motor: 7, ModularFrameLightweight: 9, ElectromagneticControlRod: 5, Rotor: 7}},
	{machine: "manufacturer", time: 32, output: {MotorLightweight: 1},
		input: {CoolingSystem: 4, ModularFrameLightweight: 2, Motor: 4, Rubber: 24}},
	{machine: "manufacturer", time: 32, output: {MotorLightweight: 2}, name: "Turbo Pressure Motor",
		input: {Motor: 4, PressureConversionCube: 1, PackagedNitrogenGas: 24, Stator: 8}},

	{machine: "blender", time:  3, output: {Battery: 1, Water: 1.5},
		input: {SulfuricAcid: 2.5, AluminaSolution: 2, AluminumCasing: 1}},
	{machine: "blender", time: 32, output: {CoolingSystem: 2}, name: "Cooling Device",
		input: {AluminumPlateReinforced: 5, Motor: 1, NitrogenGas: 24}},
	{machine: "blender", time: 10, output: {CoolingSystem: 1},
		input: {AluminumPlateReinforced: 2, Rubber: 2, Water: 5, NitrogenGas: 25}},
	{machine: "blender", time: 6, output: {LiquidFuel: 10}, name: "Diluted Fuel",
		input: {HeavyOilResidue: 5, Water: 10}},
	//This is the core recipe for Fused Modular Frames. If, as with most other core recipes, it
	//doubles the sink value of its inputs, then Nitrogen Gas must be worth 10 points per cubic meter.
	//Packaged Nitrogen Gas is worth 312 and the tank is worth 225. That leaves 87 points for 4m³ of
	//the gas. That doesn't really work.
	{machine: "blender", time: 40, output: {ModularFrameFused: 1},
		input: {ModularFrameHeavy: 1, AluminumCasing: 50, NitrogenGas: 25}},
	{machine: "blender", time: 20, output: {ModularFrameFused: 1}, name: "Heat-Fused Frame",
		input: {ModularFrameHeavy: 1, AluminumIngot: 50, UnpackageNitricAcid: 8, LiquidFuel: 10}},
	{machine: "blender", time:  6, output: {AluminumScrap: 30, Water: 5}, name: "Instant Scrap",
		input: {OreBauxite: 15, Coal: 10, SulfuricAcid: 5, Water: 6}},
	{machine: "blender", time:  6, output: {UnpackageNitricAcid: 3},
		input: {NitrogenGas: 12, Water: 3, IronPlate: 1}},
	{machine: "blender", time:  8, output: {LiquidTurboFuel: 6}, name: "Turbo Blend Fuel",
		input: {LiquidFuel: 2, HeavyOilResidue: 4, Sulfur: 3, PetroleumCoke: 3}},
];

let machine = null, sort_order = "Recipe";

function describe_ratio(value, base) {
	if (!base) return "";
	let ratio = value / base;
	if (ratio < 0.5) return " (1 : " + (1/ratio).toFixed(2) + ")";
	if (ratio < 1) return " (-" + Math.round(100 - ratio * 100) + "%)";
	if (ratio === 1.0) return " (same)";
	if (ratio < 2) return " (+" + Math.round(ratio * 100 - 100) + "%)";
	return " (" + ratio.toFixed(2) + " : 1)";
}

function threeplace(rate) {
	if (rate === Math.floor(rate)) return "" + rate;
	return rate.toFixed(3);
}
function permin(qty, time) {return threeplace(60 * qty / time) + "/min";}

let recipeinfo = { };
//Call this on any change, whatsoever. The only info retained from one call to
//another is what update_totals populates into recipeinfo.
function update_recipes() {
	if (!recipeinfo.output_items) return; //Not initialized fully yet. Wait till we have our data.
	const rows = [];
	let key = null;
	const filter = DOM('input[name="recipefilter"]:checked').value;
	switch (sort_order) {
		case "Recipe": key = ""; break; //Your Recipe always comes up first when sorting by name
		case "Machine": key = Object.values(machines).indexOf(machine); break;
		case "Inputs": key = recipeinfo.input_sink; break; //Sorting by inputs/outputs sorts by total sink value for simplicity.
		case "Outputs": key = -recipeinfo.output_sink; break;
		case "Rate":
			//TODO: If we're filtered to "Any Output", try to get the rate of a relevant output.
			//For now it just sorts by total items per minute, same as for Same Machine mode.
			if (filter === "firstoutput") key = recipeinfo.output_items[0][0];
			else key = recipeinfo.output_items.map(i => i[0]).reduce((a,b) => a+b, 0);
			key = -key / recipeinfo.time;
			break;
		case "Sink value": key = recipeinfo.output_sink && recipeinfo.input_sink / recipeinfo.output_sink; break;
		case "Energy": key = recipeinfo.output_energy && recipeinfo.input_energy / recipeinfo.output_energy; break;
		case "MJ/item":
			if (filter === "firstoutput") key = recipeinfo.output_items[0][0];
			else key = recipeinfo.output_items.map(i => i[0]).reduce((a,b) => a+b, 0);
			key = key && recipeinfo.time * machine.cost / key;
			break;
	}
	rows.push({key, pos: rows.length, row: TR({className: "yourrecipe"}, [
		TD("Your Recipe"),
		TD(machine.name),
		TD([].concat(...recipeinfo.input_items.map(i => [CODE(i[0] + " " + i[1].name), BR()]))),
		TD([].concat(...recipeinfo.output_items.map(i => [CODE(i[0] + " " + i[1].name), BR()]))),
		TD([].concat(...recipeinfo.output_items.map(i => [CODE(permin(i[0], recipeinfo.time)), BR()]))),
		TD(recipeinfo.input_sink + " makes " + recipeinfo.output_sink + describe_ratio(recipeinfo.output_sink, recipeinfo.input_sink)),
		TD(recipeinfo.output_energy ?
		   recipeinfo.input_energy + " makes " + recipeinfo.output_energy + describe_ratio(recipeinfo.output_energy, recipeinfo.input_energy)
		   : ""
		),
		TD([].concat(...recipeinfo.output_items.map(i => [CODE(threeplace(i[0] && recipeinfo.time * machine.cost / i[0])), BR()]))),
	])});
	recipes.forEach(recipe => {
		let matches = false;
		if (filter === "anyoutput") {
			for (let iq of recipeinfo.output_items)
				if (recipe.output[iq[2]]) matches = true;
		}
		else if (filter === "firstoutput") {
			//Match on the first output, treating the second output as a waste or irrelevant product.
			//Note that other recipes will match if they make that output in any slot.
			//Note also that there is currently no way to specify that a refinery's fluid output is
			//the primary one, so it will always match on the solid output.
			matches = recipeinfo.output_items.length && recipe.output[recipeinfo.output_items[0][2]];
		}
		else matches = machine === machines[recipe.machine];
		if (!matches) return;
		const info = {energyused: recipe.time * machines[recipe.machine].cost};
		["input", "output"].forEach(kwd => {
			let sink = 0, energy = 0, totitems = 0;
			const items = [], rates = [], mj = [];
			for (const [resid, qty] of Object.entries(recipe[kwd])) {
				const res = resources[resid];
				if (!res) {console.warn("Borked " + kwd + " " + resid, recipe); continue;}
				items.push(CODE(qty + " " + res.name), BR());
				rates.push(CODE(permin(qty, recipe.time)), BR());
				sink += (res.sink||0) * qty;
				energy += (res.energy||0) * qty;
				mj.push(CODE(threeplace(qty && info.energyused / qty)), BR());
				if (filter !== "firstoutput" || resid === recipeinfo.output_items[0][2]) totitems += qty;
			}
			info[kwd + "_items"] = items;
			info[kwd + "_totitems"] = totitems;
			info[kwd + "_rates"] = rates;
			info[kwd + "_sink"] = sink;
			info[kwd + "_energy"] = energy;
			info[kwd + "_mj"] = mj;
		});
		const recipename = recipe.name || (resources[Object.keys(recipe.output)[0]] || {name: ""}).name;
		let key = null;
		switch (sort_order) {
			case "Recipe": key = recipename.toLowerCase(); break;
			case "Machine": key = Object.keys(machines).indexOf(recipe.machine); break;
			case "Inputs": key = info.input_sink; break;
			case "Outputs": key = -info.output_sink; break;
			case "Rate": key = -info.output_totitems / recipe.time; break;
			case "Sink value": key = info.output_sink && info.input_sink / info.output_sink; break;
			case "Energy": key = info.output_energy && info.input_energy / info.output_energy; break;
			case "MJ/item": key = info.output_totitems && info.energyused / info.output_totitems; break;
		}
		rows.push({key, pos: rows.length, row: TR([
			TD(recipename),
			TD(machines[recipe.machine].name),
			TD(info.input_items),
			TD(info.output_items),
			TD(info.output_rates),
			TD(info.input_sink + " makes " + info.output_sink + describe_ratio(info.output_sink, info.input_sink)),
			TD(info.output_energy ?
			   info.input_energy + " makes " + info.output_energy + describe_ratio(info.output_energy, info.input_energy)
			   : ""
			),
			TD(info.output_mj),
		])});
	});
	rows.sort((a, b) => {
		if (a.key < b.key) return -1;
		if (a.key > b.key) return 1;
		//To ensure sort stability, disambiguate using the original array position.
		return a.pos - b.pos;
	});
	set_content("#recipes tbody", rows.map(r => r.row));
}

function update_totals() {
	let base_sink = -1, base_energy = -1;
	recipeinfo = {time: DOM("#time").value|0};
	["input", "output"].forEach(kwd => {
		let sink = 0, energy = 0;
		const items = [];
		for (let i = 0; i < machine[kwd].length; ++i) {
			const resid = DOM("#" + kwd + i).value;
			const res = resources[resid];
			if (!res) {console.warn("Borked " + kwd, DOM("#" + kwd + i).value); continue;}
			const qty = +DOM("#" + kwd + "qty" + i).value;
			sink += (res.sink||0) * qty;
			energy += (res.energy||0) * qty;
			if (res.sink && qty) items.push([qty, res, resid]);
		}
		recipeinfo[kwd + "_items"] = items;
		recipeinfo[kwd + "_sink"] = sink;
		recipeinfo[kwd + "_energy"] = energy;
		let desc = sink + " sink value";
		if (base_sink === -1) base_sink = sink;
		else desc += describe_ratio(sink, base_sink);
		if (energy) {
			desc += `, ${energy} MJ`;
			if (base_energy === -1) base_energy = energy;
			else desc += describe_ratio(energy, base_energy);
		}
		set_content("#" + kwd + "_total", desc);
	});
	update_recipes();
}
on("input", "#recipe input,select", update_totals);
on("click", 'input[name="recipefilter"]', update_recipes);

on("click", "#recipes th", e => {
	window.match = e.match
	sort_order = e.match.innerText.trim();
	update_recipes();
});

function RESOURCE(attrs, type) {
	const groups = {"": []};
	resource_ids[type || "a"].forEach(r => {
		const g = resources[r].group || "";
		if (!groups[g]) groups[g] = [];
		groups[g].push(OPTION({value: r}, resources[r].name));
	});
	return SELECT(attrs, groups[""].concat(Object.entries(groups).map(([grp, opts]) => grp && OPTGROUP({label: grp}, opts))));
}

function select_machine(id) {
	machine = machines[id];
	const rows = [];
	["Input", "Output"].forEach(lbl => {
		const kwd = lbl.toLowerCase();
		for (let i = 0; i < machine[kwd].length; ++i)
			rows.push(TR([TD(lbl), TD([
				RESOURCE({id: kwd + i}, machine[kwd][i]),
				INPUT({id: kwd + "qty" + i, type: "number", value: 1}),
				" = ", SPAN({id: kwd + "timedesc" + i}, "60/min"),
			])]));
		rows.push(TR([TD("Total"), TD({id: kwd + "_total"})]));
		rows.push(TR(TD({colSpan: 2})));
	});
	rows.push(TR([TD("Time"), TD([INPUT({id: "time", type: "number", value: 1}), " = ", SPAN({id: "timedesc"}, "60/min")])]));
	const stuff = [TABLE({border: 1}, rows)];
	set_content("#recipe", stuff);
	update_totals();
}
on("click", 'input[name="machine"]', e => select_machine(e.match.value));
DOM("input[name=machine][value=constructor]").checked = true; select_machine("constructor");

on("input", 'input[type="number"]', e => {
	//Yes, in theory we could have other numeric inputs, but worst case, we update unnecessarily.
	const time = DOM("#time").value|0; //I don't think non-integer times are supported by the game
	set_content("#timedesc", permin(1, time));
	["input", "output"].forEach(kwd => {
		for (let i = 0; i < machine[kwd].length; ++i)
			set_content("#" + kwd + "timedesc" + i, permin(+DOM("#" + kwd + "qty" + i).value, time));
	});
});

function collect_items(kwd) {
	const items = [];
	for (let i = 0; i < machine[kwd].length; ++i) {
		const resid = DOM("#" + kwd + i).value;
		const qty = (+DOM("#" + kwd + "qty" + i).value) * (machine[kwd][i] === 'f' ? 1000 : 1);
		if (resid !== "None" && qty) items.push({Item: "Desc_" + resid + "_C", Amount: qty});
	}
	return items;
}

on("click", "#export", e => {
	const recipe = {"$schema": "https://raw.githubusercontent.com/Nogg-aholic/ContentLib_Recipes/master/FContentLib_Recipe.json"};
	recipe.Name = DOM("#recipename").value;
	recipe.Ingredients = collect_items("input");
	recipe.Products = collect_items("output");
	recipe.ManufacturingDuration = DOM("#time").value|0;
	recipe.ProducedIn = ["Build_" + machine.id];
	if (DOM("input[name=manual]").checked) recipe.ProducedIn.push("manual");
	recipe.UnlockedBy = [DOM("#unlock").value];
	DOM("#importexport textarea").value = JSON.stringify(recipe, null, 4);
	DOM("#importexport").showModal();
});

function deploy_items(kwd, items) {
	const available = machine[kwd].split("");
	for (let item of items) {
		//NOTE: This will not fully maintain order. At best (and not currently implemented),
		//it will prioritize fluid output over solid if that's the order given.
		const resid = item.Item.replace("Desc_", "").replace("_C", "");
		const type = fluid_resources[resid] ? "f" : "s"; //If borked, assume solid... I guess
		const idx = available.indexOf(type);
		if (idx === -1) continue; //Ignore if there are too many of that type
		available[idx] = "x";
		DOM("#" + kwd + idx).value = resid;
		DOM("#" + kwd + "qty" + idx).value = item.Amount / (type === "f" ? 1000 : 1);
	}
}

on("submit", "#importexport form", e => {
	let recipe = null;
	try {recipe = JSON.parse(DOM("#importexport textarea").value);} catch (e) { }
	if (!recipe) return; //TODO: Report error
	DOM("#recipename").value = recipe.Name || "";
	(recipe.ProducedIn || []).forEach(mach => {
		const machine = Object.keys(machines).find(m => "Build_" + machines[m].id === mach);
		if (machine) {DOM("input[name=machine][value=" + machine + "]").checked = true; select_machine(machine);}
	});
	deploy_items("input", recipe.Ingredients || []);
	deploy_items("output", recipe.Products || []);
	DOM("#time").value = recipe.ManufacturingDuration || 0;
	if (recipe.UnlockedBy) DOM("#unlock").value = recipe.UnlockedBy[0];
	update_totals();
});

on("click", "#savejson", e => {
	const data = DOM("#importexport textarea").value;
	const blob = new Blob([data], {type: "application/json"});
	const url = URL.createObjectURL(blob);
	let fn = "";
	try {fn = JSON.parse(data).Name || "";} catch (e) { }
	fn = fn.replace(/[^A-Za-z]/g, "");
	if (fn === "") fn = "Example";
	A({href: url, download: "Recipe_" + fn + ".json"}).click();
	setTimeout(() => URL.revokeObjectURL(url), 60000); //Dispose of the blob after a minute - it should have finished by then
});
