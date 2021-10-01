import choc, {set_content, DOM, on} from "https://rosuav.github.io/shed/chocfactory.js";
const {TABLE, TR, TD, INPUT, SELECT, OPTION, SPAN} = choc;

//TODO: Crib these from the files somehow so they don't have to be updated.
const machines = {
	constructor: {
		input: "s",
		output: "s",
		cost: 4, //MW, or MJ/second
	},
	assembler: {
		input: "ss",
		output: "s",
		cost: 15,
	},
	refinery: {
		input: "sf",
		output: "sf",
		cost: 30,
	},
};
const solid_resources = {
	None: {sink: 0, name: "None"},
	FlowerPetals: {sink: 10, energy: 100, name: "Flower Petals"},
	Leaves: {sink: 3, energy: 15, name: "Leaves"},
	GenericBiomass: {sink: 12, energy: 180, name: "Biomass"},
	Biofuel: {sink: 48, energy: 450, name: "Solid Biofuel"},
	OreIron: {sink: 1, name: "Iron Ore"},
	IronIngot: {sink: 2, name: "Iron Ingot"},
	IronPlate: {sink: 6, name: "Iron Plate"},
	Plastic: {sink: 75, name: "Plastic"},
	SteelIngot: {sink: 8, name: "Steel Ingot"},
	CopperIngot: {sink: 6, name: "Copper Ingot"},
	GoldIngot: {sink: 42, name: "Caterium Ingot"},
	Wire: {sink: 6, name: "Wire"},
};
//Sink values of fluids are defined by their packaged equivalents, minus 60 for
//the package itself. This completely discounts any processing value from the
//package/unpackage process, since it's reversible.
const fluid_resources = {
	None: {sink: 0, name: "None"},
	Water: {sink: 70, name: "Water"},
	LiquidBiofuel: {sink: 310, energy: 750, name: "Liquid Biofuel"},
};
const resources = {...solid_resources, ...fluid_resources};
const resource_ids = {
	s: Object.keys(solid_resources),
	f: Object.keys(fluid_resources),
	a: Object.keys(resources),
};

const recipes = [
	{
		from: {IronIngot: 3},
		to: {IronPlate: 2},
		machine: "constructor",
		time: 6,
	},
	{
		name: "Coated Iron Plate",
		from: {IronIngot: 10, Plastic: 2},
		to: {IronPlate: 15},
		machine: "assembler",
		time: 12,
	},
	{
		name: "Steel Coated Plate",
		from: {SteelIngot: 3, Plastic: 2},
		to: {IronPlate: 18},
		machine: "assembler",
		time: 24,
	},
	{
		from: {CopperIngot: 1},
		to: {Wire: 2},
		machine: "constructor",
		time: 4,
	},
	{
		name: "Fused Wire",
		from: {CopperIngot: 4, GoldIngot: 1},
		to: {Wire: 30},
		machine: "assembler",
		time: 20,
	},
	{
		name: "Iron Wire",
		from: {IronIngot: 5},
		to: {Wire: 9},
		machine: "constructor",
		time: 24,
	},
	{
		name: "Caterium Wire",
		from: {GoldIngot: 1},
		to: {Wire: 8},
		machine: "constructor",
		time: 4,
	},
];

let machine = null;

function describe_ratio(value, base) {
	if (!base) return "";
	let ratio = value / base;
	if (ratio < 0.5) return " (1 : " + (1/ratio).toFixed(2) + ")";
	if (ratio < 1) return " (-" + Math.round(100 - ratio * 100) + "%)";
	if (ratio === 1.0) return " (same)";
	if (ratio < 2) return " (+" + Math.round(ratio * 100 - 100) + "%)";
	return " (" + ratio.toFixed(2) + " : 1)";
}

function update_totals() {
	let base_sink = -1, base_energy = -1;
	["input", "output"].forEach(kwd => {
		let sink = 0, energy = 0;
		for (let i = 0; i < machine[kwd].length; ++i) {
			const res = resources[DOM("#" + kwd + i).value];
			if (!res) {console.warn("Borked " + kwd, DOM("#" + kwd + i).value); continue;}
			const qty = DOM("#" + kwd + "qty" + i).value|0;
			sink += (res.sink||0) * qty;
			energy += (res.energy||0) * qty;
		}
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
}
on("input", "#recipe input,select", update_totals);

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
			rows.push(TR([TD(lbl), TD([RESOURCE({id: kwd + i}, machine[kwd][i]), INPUT({id: kwd + "qty" + i, type: "number", value: 1})])]));
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

on("input", "#time", e => {
	//TODO: Add per-minute descriptions for each input and output
	const permin = 60 / e.match.value;
	if (permin === Math.floor(permin)) set_content("#timedesc", permin + "/min");
	else set_content("#timedesc", permin.toFixed(3) + "/min");
});