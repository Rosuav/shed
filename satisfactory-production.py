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
		producers[item].append({
			"makes": Counter({item: 60}),
			"recipes": [],
			"costs": Counter({item: 1}),
		})

# If you're building on existing infrastructure, it may be easiest to
# declare some items as intrinsically available. They will be treated
# as primary production, eg "Requires 600/min Rubber".
# auto_producer("Rubber", "Coke", "Alum_Ingot")

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


class Alumina_Solution(Refinery):
	Bauxite: 12
	Water: 18
	time: 6
	Alumina: 12
	Silica: 5
class Sloppy_Alumina(Refinery):
	Bauxite: 15
	Water: 15
	time: 6
	Alumina: 18

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

'''
Ways to get Fuel
- "Diluted Fuel" Blender 5 Residue + 10 Water/6s = 10
  - <Heavy Oil Rubber> * 125%
  - Net: 3.75 Crude + 12.5 Water/6s = 10 Fuel + 1.25 Rubber; Refinery*125% + Refinery*62.5% + Blender
- "Diluted Packaged Fuel" 1 Residue + 2 Water/2s = 2, also needs 2xPackager at same clock speed
  - <Heavy Oil Rubber> * 75%
  - Net: 2.25 Crude + 7.5 Water/6s = 6 Fuel + 0.75 Rubber; Refinery*75% + Refinery*37.5% + Refinery + Packager + Packager
- "Residual Fuel" 6 Residue/6s = 4
  - "Rubber" * 3
  - Net: 9 Crude/6s = 4 Fuel + 6 Rubber; Refinery*300% + Refinery
- "Fuel" 6 Crude/6s = 4 + 3 Resin
  - "Residual Rubber" * 50%
  - Net: 6 Crude + 3 Water/6s = 4 Fuel + 3 Rubber; Refinery + Refinery * 50%

The only ways to get Resin are from Crude, and the only ways to use it involve Water.

Get Residue
- "Rubber" 3 Crude/6s = 2 Residue + 2 Rubber
- <Heavy Oil Rubber> 3 Crude + 2 Water/6s = 4 Residue + 1 Rubber; Refinery "Heavy Oil Residue" + Refinery "Residual Rubber" * 50%
'''

if __name__ == "__main__":
	import sys
	if len(sys.argv) < 2:
		print("\nERROR: Must specify one or more target items")
		sys.exit(0)
	for target in sys.argv[1:]:
		print()
		print("PRODUCING: 60/min", target)
		print("====================================")
		for recipe in producers[target]:
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

