# Calculate production rates for Satisfactory
# Requires Python 3.7, maybe newer
# I spent WAY too much time and had WAY too much fun doing this. Deal with it.

from collections import defaultdict
from fractions import Fraction

consumers = defaultdict(list)
producers = defaultdict(list)

class Building:
	@classmethod
	def __init_subclass__(bldg):
		super().__init_subclass__()
		print("Building:", bldg.__name__)
		def make_recipe(recip):
			print(recip.__name__.replace("_", " "), "is made in a", bldg.__name__)
			needs, makes = defaultdict(int), defaultdict(int)
			per_minute = None
			for item, qty in recip.__dict__.items():
				if item.startswith("_"): continue
				if item == "time":
					recip.time = qty
					per_minute = Fraction(60, time)
					if per_minute == int(per_minute): per_minute = int(per_minute)
					continue
				item = item.strip("_")
				if per_minute is None:
					needs[item] += qty
					consumers[item].append(recip)
				else:
					makes[item] += qty
					producers[item].append(recip)
			recip.needs = {i: q * per_minute for i, q in needs.items()}
			recip.makes = {i: q * per_minute for i, q in makes.items()}
		bldg.__init_subclass__ = classmethod(make_recipe)


class Refinery(Building): ...
class Blender(Building): ...
class Packager(Building): ...

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
	Plastic: 2

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

class Diluted_Packaged_Fuel(Refinery):
	Residue: 1
	Packaged_Water: 2
	time: 2
	Packaged_Fuel: 2
class Package_Water(Packager):
	Water: 2
	Canister: 2
	time: 2
	Packaged_Water: 2
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
