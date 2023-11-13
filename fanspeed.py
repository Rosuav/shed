import time
import sensors
# A lot of this is hard-coded to Sikorsky, I haven't (yet) tried to make it generic.
CHIPNAME = "nct6798-isa-0290"
FANS = "fan1", "fan2", "fan4", "fan7"

sensors.init()
chip = next(sensors.ChipIterator(CHIPNAME))
fans = [None] * len(FANS)
for feature in sensors.FeatureIterator(chip):
	name = feature.name.decode()
	try: fans[FANS.index(name)] = feature
	except ValueError: pass
if None in fans:
	print("NOT ALL FANS FOUND")
	for fan, name in zip(fans, FANS):
		if fan is None: print("Not found:", name)
	fans = [fan for fan in fans if fan is not None]
	# Carry on with a reduced set of fans
inputs = []
for fan in fans:
	for sf in sensors.SubFeatureIterator(chip, fan):
		if sf.name.endswith(b"_input"): # Is this the best way to recognize it?
			inputs.append(sf.number)
			break
	else:
		print("NOT ALL FANS HAVE _input ATTRIBUTES")
		print("Failing fan:", fan.name.decode())
		inputs.append(None)

while True:
	for fan, input in zip(fans, inputs):
		if input is None: continue # failed above
		value = sensors.get_value(chip, input)
		print(fan.name.decode(), value)
	print()
	time.sleep(1)
	print("\x1b[%dA" % (len(fans) + 1), end="")
