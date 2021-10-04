import choc, {set_content, DOM, on} from "https://rosuav.github.io/shed/chocfactory.js";
const {BR, CODE, TABLE, TR, TD, INPUT, SELECT, OPTION, SPAN} = choc;
//TODO: Check styles, esp colours, on GH Pages

//TODO: Crib these from the files somehow so they don't have to be updated.
const machines = {
	constructor: {
		name: "Constructor",
		input: "s",
		output: "s",
		cost: 4, //MW, or MJ/second
	},
	smelter: {
		name: "Smelter",
		input: "s",
		output: "s",
		cost: 4,
	},
	assembler: {
		name: "Assembler",
		input: "ss",
		output: "s",
		cost: 15,
	},
	foundry: {
		name: "Foundry",
		input: "ss",
		output: "s",
		cost: 16,
	},
	refinery: {
		name: "Refinery",
		input: "sf",
		output: "sf",
		cost: 30,
	},
};
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
	Plastic: {sink: 75, name: "Plastic"},
	IronPlateReinforced: {sink: 120, name: "Reinforced Iron Plate"},
	PackagedWater: {sink: 130, name: "Packaged Water"},
	AluminumIngot: {sink: 131, name: "Aluminum Ingot"},
	Rotor: {sink: 140, name: "Rotor"},
	PackagedSulfuricAcid: {sink: 152, name: "Packaged Sulfuric Acid"},
	PackagedAlumina: {sink: 160, name: "Packaged Alumina Solution"},
	PackagedOil: {sink: 160, energy: 320, name: "Packaged Oil", unpackaged: "LiquidOil"},
	PackagedOilResidue: {sink: 180, energy: 400, name: "Packaged Heavy Oil Residue", unpackaged: "HeavyOilResidue"},
	GasTank: {sink: 225, name: "Empty Fluid Tank"},
	Stator: {sink: 240, name: "Stator"},
	AluminumPlate: {sink: 266, name: "Alclad Aluminum Sheet"},
	Fuel: {sink: 270, energy: 750, name: "Packaged Fuel", unpackaged: "LiquidFuel"},
	PackagedNitrogenGas: {sink: 312, name: "Packaged Nitrogen Gas"},
	EquipmentDescriptorBeacon: {sink: 320, name: "Beacon"},
	PackagedBiofuel: {sink: 370, energy: 750, name: "Packaged Liquid Biofuel", unpackaged: "LiquidBiofuel"},
	AluminumCasing: {sink: 393, name: "Aluminum Casing"},
	ModularFrame: {sink: 408, name: "Modular Frame"},
	TurboFuel: {sink: 570, energy: 2000, name: "Packaged Turbofuel", unpackaged: "LiquidTurboFuel"},
	SteelPlateReinforced: {sink: 632, name: "Encased Industrial Beam"},
	CircuitBoard: {sink: 696, name: "Circuit Board"},
	CircuitBoardHighSpeed: {sink: 920, name: "AI Limiter"},
	Motor: {sink: 1520, name: "Motor"},
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
			sink: r.sink - solid_resources[r.pkg || "FluidCanister"].sink,
			name: r.unpkgname || r.name.replace("Packaged ", ""),
		};
	}
}
const resource_ids = {
	s: Object.keys(solid_resources),
	f: Object.keys(fluid_resources),
	a: Object.keys(resources),
};

//Recipe order doesn't matter much as the display is usually sorted by something more relevant.
const recipes = [
	//Constructor
	{machine: "constructor", time: 6, input: {IronIngot: 3}, output: {IronPlate: 2}},
	{machine: "constructor", time: 4, input: {CopperIngot: 1}, output: {Wire: 2}},
	{machine: "constructor", time: 24, input: {IronIngot: 5}, output: {Wire: 9}, name: "Iron Wire"},
	{machine: "constructor", time: 4, input: {GoldIngot: 1}, output: {Wire: 8}, name: "Caterium Wire"},
	{machine: "constructor", time: 2, input: {AluminumIngot: 3}, output: {AluminumCasing: 2}},
	{machine: "constructor", time: 2, input: {GenericBiomass: 5}, output: {Coal: 6}, name: "Biocoal"},
	//Smelter
	{machine: "smelter", time: 2, input: {OreIron: 1}, output: {IronIngot: 1}},
	{machine: "smelter", time: 2, input: {OreCopper: 1}, output: {CopperIngot: 1}},
	{machine: "smelter", time: 4, input: {OreGold: 3}, output: {GoldIngot: 1}},
	{machine: "smelter", time: 2, input: {AluminumScrap: 2}, output: {AluminumIngot: 1}, name: "Pure Aluminum Ingot"},
	//Foundry
	{machine: "foundry", time: 4, input: {OreIron: 3, Coal: 3}, output: {SteelIngot: 3}},
	{machine: "foundry", time: 3, input: {IronIngot: 2, Coal: 2}, output: {SteelIngot: 3}, name: "Solid Steel Ingot"},
	{machine: "foundry", time: 12, input: {OreIron: 15, PetroleumCoke: 15}, output: {SteelIngot: 20}, name: "Coke Steel Ingot"},
	{machine: "foundry", time: 16, input: {OreIron: 6, CompactedCoal: 3}, output: {SteelIngot: 10}, name: "Compacted Steel Ingot"},
	{machine: "foundry", time: 12, input: {OreCopper: 10, OreIron: 5}, output: {CopperIngot: 20}, name: "Copper Alloy Ingot"},
	{machine: "foundry", time: 6, input: {OreIron: 2, OreCopper: 2}, output: {IronIngot: 5}, name: "Iron Alloy Ingot"},
	{machine: "foundry", time: 4, input: {AluminumScrap: 6, Silica: 5}, output: {AluminumIngot: 4}},

	{
		name: "Coated Iron Plate",
		input: {IronIngot: 10, Plastic: 2},
		output: {IronPlate: 15},
		machine: "assembler",
		time: 12,
	},
	{
		name: "Steel Coated Plate",
		input: {SteelIngot: 3, Plastic: 2},
		output: {IronPlate: 18},
		machine: "assembler",
		time: 24,
	},
	{
		name: "Fused Wire",
		input: {CopperIngot: 4, GoldIngot: 1},
		output: {Wire: 30},
		machine: "assembler",
		time: 20,
	},
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

function permin(qty, time) {
	const rate = 60 * qty / time;
	if (rate === Math.floor(rate)) return rate + "/min";
	return rate.toFixed(3) + "/min";
}

let recipeinfo = { };
//Call this on any change, whatsoever. The only info retained from one call to
//another is what update_totals populates into recipeinfo.
function update_recipes() {
	if (!recipeinfo.output_items) return; //Not initialized fully yet. Wait till we have our data.
	const rows = [];
	let key = null;
	switch (sort_order) {
		case "Recipe": key = ""; break; //Your Recipe always comes up first when sorting by name
		case "Machine": key = Object.values(machines).indexOf(machine); break;
		case "Inputs": key = recipeinfo.input_sink; break; //Sorting by inputs/outputs sorts by total sink value for simplicity.
		case "Outputs": key = -recipeinfo.output_sink; break;
		case "Rate":
			//TODO: If we're filtered to "Same Output", try to get the rate of a relevant output.
			//For now it just sorts by total sink value per minute.
			key = -recipeinfo.output_sink / recipeinfo.time;
			break;
		case "Sink value": key = recipeinfo.output_sink && recipeinfo.input_sink / recipeinfo.output_sink; break;
		case "Energy": key = recipeinfo.output_energy && recipeinfo.input_energy / recipeinfo.output_energy; break;
	}
	rows.push({key, pos: rows.length, row: TR({className: "highlight"}, [
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
	])});
	const filter = DOM('input[name="recipefilter"]:checked').value;
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
		const info = { };
		["input", "output"].forEach(kwd => {
			let sink = 0, energy = 0;
			const items = [], rates = [];
			for (const [resid, qty] of Object.entries(recipe[kwd])) {
				const res = resources[resid];
				if (!res) {console.warn("Borked " + kwd + " " + resid, recipe); continue;}
				items.push(CODE(qty + " " + res.name), BR());
				rates.push(CODE(permin(qty, recipe.time)), BR());
				sink += (res.sink||0) * qty;
				energy += (res.energy||0) * qty;
			}
			info[kwd + "_items"] = items;
			info[kwd + "_rates"] = rates;
			info[kwd + "_sink"] = sink;
			info[kwd + "_energy"] = energy;
		});
		const recipename = recipe.name || resources[Object.keys(recipe.output)[0]].name;
		let key = null;
		switch (sort_order) {
			case "Recipe": key = recipename.toLowerCase(); break;
			case "Machine": key = Object.keys(machines).indexOf(recipe.machine); break;
			case "Inputs": key = info.input_sink; break;
			case "Outputs": key = -info.output_sink; break;
			case "Rate": key = -info.output_sink / recipe.time; break; //TODO as above - relevant output?
			case "Sink value": key = info.output_sink && info.input_sink / info.output_sink; break;
			case "Energy": key = info.output_energy && info.input_energy / info.output_energy; break;
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
			const qty = DOM("#" + kwd + "qty" + i).value|0;
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
	//TODO: optgroup these as appropriate
	return SELECT(attrs, resource_ids[type || "a"].map(r => OPTION({value: r}, resources[r].name)));
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
select_machine("constructor");

on("input", 'input[type="number"]', e => {
	//Yes, in theory we could have other numeric inputs, but worst case, we update unnecessarily.
	const time = DOM("#time").value|0; //I don't think non-integer times are supported by the game
	set_content("#timedesc", permin(1, time));
	["input", "output"].forEach(kwd => {
		for (let i = 0; i < machine[kwd].length; ++i)
			set_content("#" + kwd + "timedesc" + i, permin(DOM("#" + kwd + "qty" + i).value|0, time));
	});
});
