# Calculate production rates for Satisfactory
# Requires Python 3.7, maybe newer
# I spent WAY too much time and had WAY too much fun doing this. Deal with it.

from collections import defaultdict, Counter
from fractions import Fraction
import itertools

consumers = defaultdict(list)
producers = defaultdict(list)

class Counter(Counter):
	try:
		Counter() <= Counter() # Fully supported on Python 3.10+
	except TypeError:
		# Older Pythons can't do multiset comparisons. Subtracting
		# one counter from another will give an empty counter (since
		# negatives are excluded) if it's a subset, so we use that.
		def __le__(self, other):
			return not (self - other)
		def __gt__(self, other):
			return not (self <= other)
	try:
		Counter() * 3 # Not supported on any known Python, but hey, might happen!
	except TypeError:
		# It's convenient to be able to multiply a counter by a number to
		# scale it. Any numeric type should be a valid scalar. I take no
		# responsibility for confusion caused by complex scalars :)
		def __mul__(self, other):
			return type(self)({k: v*other for k,v in self.items()})

def auto_producer(*items):
	# If anything is called on as a resource without being generated,
	# describe it as a fundamental need.
	for item in items:
		# print("\x1b[1;32mAutoproducer:", item, "\x1b[0m")
		producers[item] = [{
			"makes": Counter({item: 60}),
			"recipes": [],
			"costs": Counter({item: 1}),
			"sources": producers[item], # If you want to delve deeper, check here.
		}]

# If you're building on existing infrastructure, it may be easiest to
# declare some items as intrinsically available. They will be treated
# as primary production, eg "Requires Circuit_Board at 600/min". Note
# that some items become intrinsic part way through to put a limit on
# the ever-growing complexity of recipes; it's not very useful to say
# that a Supercomputer requires X Crude and Y Bauxite with a gigantic
# matrix of different Xs and Ys.
# auto_producer("Circuit_Board")

class Building:
	resource = None
	@classmethod
	def __init_subclass__(bldg):
		super().__init_subclass__()
		# print("Building:", bldg.__name__)
		def make_recipe(recip):
			# print(recip.__name__.replace("_", " "), "is made in a", bldg.__name__.replace("_", " "))
			recip.building = bldg
			makes = defaultdict(int)
			per_minute = None
			needs, needqty = [], []
			for item, qty in recip.__annotations__.items():
				if item.startswith("_"): continue
				qty = int(qty)
				if item == "time":
					per_minute = Fraction(60, qty)
					continue
				item = item.strip("_")
				if per_minute is None:
					if not producers[item]:
						# raise Exception("Don't know how to obtain %s for %s" % (item, recip.__name__))
						auto_producer(item)
					needs.append(producers[item])
					needqty.append(qty)
					makes[item] -= qty
				else:
					makes[item] += qty
			# Scan the requirements and exclude any that are strictly worse
			# than others. This is O(n²) in the number of options, which are
			# the product of all options, but there shouldn't ever be TOO
			# many; the strictly-worse check will guard against loops. Note
			# that many requirements will have only a single producer.
			for requirements in itertools.product(*needs):
				net = Counter({i: q * per_minute for i, q in makes.items()})
				costs = Counter()
				if recip.resource: costs[recip.resource] = 1
				recipes = []
				for req, qty in zip(requirements, needqty):
					ratio = Fraction(qty * per_minute, 60)
					for i, q in req["makes"].items():
						net[i] += q * ratio
					for i, q in req["costs"].items():
						costs[i] += q * ratio
					for r, q in req["recipes"]:
						recipes.append((r, q * ratio))
				if -net:
					raise Exception("Shouldn't happen! Makes a negative qty! " + recip.__name__)
				net -= Counter() # Clean out any that have hit zero
				recipes.append((recip, 1))
				for item, qty in net.items():
					ratio = Fraction(60, qty)
					scaled_costs = costs * ratio # Cost to produce 60/min of this product
					for alternate in producers[item]:
						if not alternate["recipes"]: break # Anything directly obtained should always be so.
						alt_costs = alternate["costs"]
						if scaled_costs >= alt_costs:
							# Strictly worse. Skip it. Note that a recipe may be
							# strictly worse for one product while being viable
							# for another; this is very common with byproducts,
							# such as run-off water from aluminium production -
							# you wouldn't want to obtain water that way, even
							# though technically you could.
							break
						if scaled_costs < alt_costs:
							# Strictly better. Remove the other one (after the loop).
							# It shouldn't be possible to be strictly better than
							# one recipe AND strictly worse than another, so we can
							# assume that we'll never break after hitting this.
							alternate["deprecated"] = 1
					else:
						producers[item].append({
							"makes": net * ratio,
							"recipes": [(r, q * ratio) for r,q in recipes],
							"costs": scaled_costs,
						})
					producers[item] = [p for p in producers[item] if "deprecated" not in p]
		bldg.__init_subclass__ = classmethod(make_recipe)


# TODO: Record power costs for each of these
class Refinery(Building): ...
class Blender(Building): ...
class Packager(Building): ...
class Constructor(Building): ...
class Assembler(Building): ...
class Manufacturer(Building): ...
class Particle_Accelerator(Building): ...
class Smelter(Building): ...
class Foundry(Building): ...

# class Recipe_Name(BuildingThatMakesIt):
#   Ingredient1: Qty
#   Ingredient2: Qty
#   time: SecondsToProduce
#   Product1: Qty
#   Product2: Qty
# If the same item is an ingredient and a product, suffix one with "_", eg with
# the production of uranium pellets (Sulfuric_Acid: 8, ..., Sulfuric_Acid_: 2).

# Basic crude refinement
class Plastic(Refinery):
	Crude: 3
	time: 6
	Residue: 1
	Plastic: 2

class Rubber(Refinery):
	Crude: 3
	time: 6
	Residue: 2
	Rubber: 2

class Fuel(Refinery):
	Crude: 6
	time: 6
	Fuel: 4
	Resin: 3

class Heavy_Oil_Residue(Refinery):
	Crude: 3
	time: 6
	Residue: 4
	Resin: 2

class Polymer_Resin(Refinery):
	Crude: 6
	time: 6
	Residue: 2
	Resin: 13

# Second-level refinement
class Residual_Fuel(Refinery):
	Residue: 6
	time: 6
	Fuel: 4

class Diluted_Fuel(Blender):
	Residue: 5
	Water: 10
	time: 6
	Fuel: 10

class Canister(Constructor):
	Plastic: 2
	time: 4
	Canister: 4

class Package_Water(Packager):
	Water: 2
	Canister: 2
	time: 2
	Packaged_Water: 2
class Diluted_Packaged_Fuel(Refinery):
	Residue: 1
	Packaged_Water: 2
	time: 2
	Packaged_Fuel: 2
class Unpackage_Fuel(Packager):
	Packaged_Fuel: 2
	time: 2
	Fuel: 2
	Canister: 2

class Petroleum_Coke(Refinery):
	Residue: 4
	time: 6
	Coke: 12

class Residual_Plastic(Refinery):
	Resin: 6
	Water: 2
	time: 6
	Plastic: 2

class Residual_Rubber(Refinery):
	Resin: 4
	Water: 4
	time: 6
	Rubber: 2

class Recycled_Plastic(Refinery):
	Fuel: 6
	Rubber: 6
	time: 12
	Plastic: 12

class Recycled_Rubber(Refinery):
	Fuel: 6
	Plastic: 6
	time: 12
	Rubber: 12

class Compacted(Assembler):
	Coal: 5
	Sulfur: 5
	time: 12
	Compacted: 5

# Making Turbofuel
class Turbofuel(Refinery):
	Fuel: 6
	Compacted: 4
	time: 16
	Turbofuel: 5

class Turbo_Heavy_Fuel(Refinery):
	Residue: 5
	Compacted: 4
	time: 8
	Turbofuel: 4

class Turbo_Blend_Fuel(Blender):
	Residue: 4
	Fuel: 2
	Sulfur: 3
	Coke: 3
	time: 8
	Turbofuel: 6

# Petroleum products are sufficiently complicated that it's worth calculating
# them first, and then treating them as fundamentals for everything else.
auto_producer("Plastic", "Rubber", "Coke", "Fuel")

class Silica(Constructor):
	Quartz: 3
	time: 8
	Silica: 5

class Alumina_Solution(Refinery):
	Bauxite: 12
	Water: 18
	time: 6
	Alumina: 12
	Silica: 5
class Sloppy_Alumina(Refinery):
	Bauxite: 10
	Water: 10
	time: 3
	Alumina: 12

class Sulfuric_Acid(Refinery):
	Sulfur: 5
	Water: 5
	time: 6
	Sulfuric_Acid: 5

class Instant_Scrap(Blender):
	Bauxite: 15
	Coal: 10
	Sulfuric_Acid: 5
	Water: 11
	time: 6
	Alum_Scrap: 30
	Water_: 4

class Aluminum_Scrap(Refinery):
	Alumina: 4
	Coal: 2
	time: 1
	Alum_Scrap: 6
	Water: 2

class Electrode_Scrap(Refinery):
	Alumina: 12
	Coke: 4
	time: 4
	Alum_Scrap: 20
	Water: 7

class Aluminum_Ingot(Foundry):
	Alum_Scrap: 6
	Silica: 5
	time: 4
	Alum_Ingot: 4

class Pure_Alum_Ingot(Smelter):
	Alum_Scrap: 2
	time: 2
	Alum_Ingot: 1

class Alclad_Sheet(Assembler):
	Alum_Ingot: 3
	Copper_Ingot: 1
	time: 6
	Alclad_Sheet: 3

class Alum_Casing(Constructor):
	Alum_Ingot: 3
	time: 2
	Alum_Casing: 2

class Alclad_Casing(Assembler):
	Alum_Ingot: 20
	Copper_Ingot: 10
	time: 8
	Alum_Casing: 15

# As with petroleum, simplify future recipes by making these fundamental.
auto_producer("Alum_Ingot", "Alum_Casing", "Alclad_Sheet", "Silica")

class Heat_Sink(Assembler):
	Alclad_Sheet: 5
	Copper_Sheet: 3
	time: 8
	Heat_Sink: 1

class Heat_Exchanger(Assembler):
	Alum_Casing: 3
	Rubber: 3
	time: 6
	Heat_Sink: 1

class Radio_Control_Unit(Manufacturer):
	Alum_Casing: 32
	Oscillator: 1
	Computer: 1
	time: 48
	Radio_Control_Unit: 2

class Radio_Control_System(Manufacturer):
	Oscillator: 1
	Circuit_Board: 10
	Alum_Casing: 60
	Rubber: 30
	time: 40
	Radio_Control_Unit: 3

class Radio_Connection_Unit(Manufacturer):
	Heat_Sink: 4
	HS_Connector: 2
	Quartz: 12
	time: 16
	Radio_Control_Unit: 1

class Cooling_System(Blender):
	Heat_Sink: 2
	Rubber: 2
	Water: 5
	Nitrogen: 25
	time: 10
	Cooling_System: 1

class Cooling_Device(Blender):
	Heat_Sink: 5
	Motor: 1
	Nitrogen: 24
	time: 32
	Cooling_System: 2

class Battery(Blender):
	Sulfuric_Acid: 3
	Alumina: 2
	Alum_Casing: 1
	time: 3
	Battery: 1
	Water: 2

class Classic_Battery(Manufacturer):
	Sulfur: 6
	Alclad_Sheet: 7
	Plastic: 8
	Wire: 12
	time: 8
	Battery: 4

class Electromagnetic_Control_Rod(Assembler):
	Stator: 3
	AI_Limiter: 2
	time: 15
	Control_Rod: 2

class Electromagnetic_Connection_Rod(Assembler):
	Stator: 2
	HS_Connector: 1
	time: 15
	Control_Rod: 2

class Supercomputer(Manufacturer): # TODO: Verify that the recipe hasn't changed in Experimental
	Computer: 2
	AI_Limiter: 2
	HS_Connector: 3
	Plastic: 28
	time: 32
	Supercomputer: 1

class OC_Supercomputer(Assembler):
	Radio_Control_Unit: 3
	Cooling_System: 3
	time: 20
	Supercomputer: 1

class Super_State_Computer(Manufacturer):
	Computer: 3
	Control_Rod: 2
	Battery: 20
	Wire: 45
	time: 50
	Supercomputer: 2

class Nitric_Acid(Blender):
	Nitrogen: 24
	Water: 6
	Iron_Plate: 1
	time: 6
	Nitric_Acid: 6

class Fused_Modular_Frame(Blender):
	Heavy_Frame: 1
	Alum_Casing: 50
	Nitrogen: 25
	time: 40
	Fused_Frame: 1

class Heat_Fused_Frame(Blender):
	Heavy_Frame: 1
	Alum_Ingot: 50
	Nitric_Acid: 8
	Fuel: 10
	time: 20
	Fused_Frame: 1

class Pressure_Conversion_Cube(Assembler):
	Fused_Frame: 1
	Radio_Control_Unit: 2
	time: 60
	Pressure_Conversion_Cube: 1

class Fluid_Tank(Constructor):
	Alum_Ingot: 1
	time: 1
	Fluid_Tank: 1

class Packaged_Nitrogen_Gas(Packager):
	Nitrogen: 4
	Fluid_Tank: 1
	time: 1
	Packaged_Nitrogen_Gas: 1

class Turbo_Motor(Manufacturer):
	Cooling_System: 4
	Radio_Control_Unit: 2
	Motor: 4
	Rubber: 24
	time: 32
	Turbo_Motor: 1

class Turbo_Rigour_Motor(Manufacturer): # TODO: Is this still a thing in Experimental?
	Motor: 7
	Radio_Control_Unit: 5
	AI_Limiter: 9
	Stator: 7
	time: 64
	Turbo_Motor: 3

class Turbo_Electric_Motor(Manufacturer):
	Motor: 7
	Radio_Control_Unit: 9
	Control_Rod: 5
	Rotor: 7
	time: 64
	Turbo_Motor: 3

class Turbo_Pressure_Motor(Manufacturer):
	Motor: 4
	Pressure_Conversion_Cube: 1
	Packaged_Nitrogen_Gas: 24
	Stator: 8
	time: 32
	Turbo_Motor: 2

# Project parts, final tier
class Copper_Powder(Constructor):
	Copper_Ingot: 30
	time: 6
	Copper_Powder: 5

class Assembly_Director_System(Assembler):
	Adaptive_Control_Unit: 2
	Supercomputer: 1
	time: 80
	Assembly_Director_System: 1

class Magnetic_Field_Generator(Manufacturer):
	Versatile_Framework: 5
	Control_Rod: 2
	Battery: 10
	time: 120
	Magnetic_Field_Generator: 2

class Nuclear_Pasta(Particle_Accelerator):
	Copper_Powder: 200
	Pressure_Conversion_Cube: 1
	time: 120
	Nuclear_Pasta: 1

class Thermal_Propulsion_Rocket(Manufacturer):
	Modular_Engine: 5
	Turbo_Motor: 2
	Cooling_System: 6
	Fused_Frame: 2
	time: 120
	Thermal_Propulsion_Rocket: 2

# Nuclear power
auto_producer("Heat_Sink", "Pressure_Conversion_Cube", "Control_Rod")

class Encased_Uranium_Cell(Blender):
	Uranium: 10
	Concrete: 3
	Sulfuric_Acid: 8
	time: 12
	Encased_Uranium_Cell: 5
	Sulfuric_Acid_: 2

class Infused_Uranium_Cell(Manufacturer):
	Uranium: 4
	Silica: 3
	Sulfur: 5
	Quickwire: 15
	time: 12
	Encased_Uranium_Cell: 4

class Uranium_Fuel_Rod(Manufacturer):
	Encased_Uranium_Cell: 50
	Encased_Beam: 3
	Control_Rod: 5
	time: 150
	Nuclear_Fuel_Rod: 1

class Nonfissile_Uranium(Blender):
	Nuclear_Waste: 15
	Silica: 10
	Nitric_Acid: 6
	Sulfuric_Acid: 6
	time: 24
	Nonfissile_Uranium: 20
	Water: 6

class Fertile_Uranium(Blender):
	Uranium: 5
	Nuclear_Waste: 5
	Nitric_Acid: 3
	Sulfuric_Acid: 5
	time: 12
	Nonfissile_Uranium: 20
	Water: 8

class Plutonium_Pellet(Particle_Accelerator):
	Nonfissile_Uranium: 100
	Nuclear_Waste: 25
	time: 60
	Plutonium_Pellet: 30

class Encased_Plutonium_Cell(Assembler):
	Plutonium_Pellet: 2
	Concrete: 4
	time: 12
	Encased_Plutonium_Cell: 1

class Instant_Plutonium_Cell(Particle_Accelerator):
	Nonfissile_Uranium: 150
	Alum_Casing: 20
	time: 120
	Encased_Plutonium_Cell: 20

class Plutonium_Fuel_Rod(Manufacturer):
	Encased_Plutonium_Cell: 30
	Steel_Beam: 18
	Control_Rod: 6
	Heat_Sink: 10
	time: 240
	Plutonium_Fuel_Rod: 1

class Plutonium_Fuel_Unit(Assembler):
	Encased_Plutonium_Cell: 20
	Pressure_Conversion_Cube: 1
	time: 120
	Plutonium_Fuel_Rod: 1


if __name__ == "__main__":
	import sys
	if len(sys.argv) < 2:
		print("\nERROR: Must specify one or more target items")
		sys.exit(0)
	for target in sys.argv[1:]:
		print()
		print("PRODUCING: 60/min", target)
		print("====================================")
		p = producers[target]
		if p and "sources" in p[0]:
			# It's been made fundamental for the benefit of future recipes,
			# but we want the actual sources.
			p = p[0]["sources"]
		for recipe in p:
			for input, qty in recipe["costs"].most_common():
				if isinstance(input, str):
					qty *= 60
					if qty != int(qty): qty = "%.2f" % float(qty)
					print("Requires %s at %s/min" % (input, qty))
			for result, qty in recipe["makes"].most_common():
				if result == target: continue # They'll all produce 60/min of the target
				if qty != int(qty): qty = "%.2f" % float(qty)
				print("Also produces %s/min %s" % (qty, result))
			for step, qty in recipe["recipes"]:
				print("%s - %s at %.2f%%" % (
					step.__name__.replace("_", " "),
					step.building.__name__.replace("_", " "),
					qty * 100.0,
				))
			print()

