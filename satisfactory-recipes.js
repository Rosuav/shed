import choc, {set_content, DOM, on} from "https://rosuav.github.io/shed/chocfactory.js";
const {TABLE, TR, TD, INPUT, SELECT, OPTION} = choc;

//TODO: Crib these from the files somehow so they don't have to be updated.
const machines = {
	constructor: {
		inputs: 1,
		outputs: 1,
		cost: 4, //MW, or MJ/second
	},
	assembler: {
		inputs: 2,
		outputs: 1,
		cost: 15,
	},
};
const resources = {
	FlowerPetals: {sink: 10, energy: 100, name: "Flower Petals"},
	GenericBioMass: {sink: 12, energy: 180, name: "Biomass"},
};
const resource_ids = Object.keys(resources); //We iterate over resources a lot.

let machine = null;
function RESOURCE(attrs) {
	//TODO: optgroup these as appropriate
	return SELECT(attrs, resource_ids.map(r => OPTION({value: r}, resources[r].name)));
}

on("click", 'input[name="machine"]', e => {
	machine = machines[e.match.value];
	const rows = [];
	for (let i = 0; i < machine.inputs; ++i)
		rows.push(TR([TD("Input"), TD([RESOURCE({id: "input" + i}), INPUT({id: "inqty" + i, type: "number"})])]));
	for (let i = 0; i < machine.outputs; ++i)
		rows.push(TR([TD("Output"), TD([RESOURCE({id: "output" + i}), INPUT({id: "outqty" + i, type: "number"})])]));
	const stuff = [TABLE({border: 1}, rows)];
	set_content("#recipe", stuff);
});
