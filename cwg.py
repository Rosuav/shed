# We're cooking with gas
import collections
import subprocess
import time
from PIL import ImageGrab # ImportError? pip install Pillow

# Define digits with bitmaps. Each number is a vertical slice, 
digits = [
	[2044, 4094, 7182, 6147, 6147, 7182, 4094, 2040], # 0
	[6152, 6156, 6150, 8190, 8190, 8190, 6144, 6144], # 1
	[7180, 7694, 7942, 7043, 6594, 6374, 6270, 6204], # 2
	[3084, 7694, 6150, 6338, 6343, 7678, 8126, 3868], # 3
	[ 768,  992,  624,  540, 1550, 8190, 8190, 1792], # 4
	[3326, 7422, 6254, 6242, 6242, 7394, 8162, 4034], # 5
	[2040, 4094, 7374, 6246, 6243, 7398, 8134, 4036], # 6
	[   6,    6, 7686, 8070,  998,  126,   30,   14], # 7
	[3996, 8190, 6374, 6210, 6211, 6374, 8190, 3996], # 8
	[3196, 7422, 6598, 6531, 6278, 7374, 4094, 2044], # 9
]
mL = [8176, 8184, 8176, 48, 16, 56, 8176, 8176, 96, 16, 24, 8184, 8176, 8160, 0, 0, 8191, 8191, 8191]
cups = [1016, 4092, 3870, 7174, 6150, 6147, 6151, 6150, 7182, 3598, 1548, 0, 0, 2032, 8184, 8176, 6144, 6144, 2048, 8176, 8184, 8176, 0, 0, 8176, 8184, 8176, 2096, 6160, 6168, 7288, 8176, 2016, 0, 0, 2272, 7408, 6608, 4504, 4504, 7056, 7984, 3872]
CHAR_WIDTH = len(digits[0]) # After we find a character, we skip forward this many pixels

def read_stripe(screen, xpos, ypos):
	stripe = 0
	for y in range(13):
		if screen.getpixel((xpos, ypos + y))[0] < 0x60: stripe |= 1 << y
	return stripe

# Read a character and determine its bitmap
def read_char(screen, xpos, ypos):
	char = []
	for x in range(8):
		stripe = read_stripe(screen, xpos + x, ypos)
		print(f"{stripe:016b}")
		char.append(stripe)
	print(char)
#read_char(ImageGrab.grab(), 995, 622)

def read_image(screen, xpos, ypos):
	for y in range(ypos, ypos + 13):
		for x in range(xpos, xpos + 17): # Try for two digits
			print("X" if screen.getpixel((x, y))[0] < 0x60 else " ", end="")
		print()
#read_image(ImageGrab.grab(), 994, 622)

def read_row(screen, xpos, ypos, width, show_unit=False, assume_decimal=False):
	xmax = xpos + width
	xpos -= 1 # Allow the increment to happen at the top of the loop
	number = integer = 0
	have_decimal = 0
	post_number = []
	while xpos < xmax:
		xpos += 1 # This logically belongs at the bottom of the loop, but it's easier to use 'continue' if it's at the top
		stripe = read_stripe(screen, xpos, ypos)
		#print(f"{stripe:013b}"); continue
		# Everything after the number could be a unit that matters to us
		if stripe or post_number: post_number.append(stripe)
		if stripe == 0: continue # Empty column, step forward
		if (bin(stripe)[2:].strip("0") == "111" # Decimal point? It has three 1s in a block and nothing else
			and read_stripe(screen, xpos + 1, ypos) == stripe
			and read_stripe(screen, xpos + 2, ypos) == stripe
			and read_stripe(screen, xpos + 3, ypos) == 0):
				integer = number
				number = 0
				have_decimal = 1
		# Nudge the search up and down a little for best matching
		best = 0, 0
		for yoffset in -2, -1, 0, 1, 2:
			likely = [0] * 10
			for i in range(CHAR_WIDTH):
				stripe = read_stripe(screen, xpos + i, ypos + yoffset)
				for digit, bitmap in enumerate(digits):
					if bitmap[i] == stripe: likely[digit] += 1
			# Pick the most likely. We assume that, most of the time, the bitmaps will exactly match;
			# in the event of something not quite matching, chances are a few of the stripes will still.
			digit, quality = max(enumerate(likely), key=lambda x: x[1])
			if quality > best[1]: best = digit, quality
		digit, quality = best
		if quality < 4: continue # Bad match, slide forward a pixel and try again
		number = (number * 10) + digit
		if have_decimal: have_decimal += 1 # Count how many digits we get after the decimal
		xpos += CHAR_WIDTH
		post_number = []
	#for stripe in post_number:
	#	print(f"{stripe:013b}")
	if assume_decimal and not have_decimal: have_decimal = 1 # In some contexts, even without a decimal provided, return a value scaled by 100 anyway
	if have_decimal:
		# Return fixed-place integer rather than float. The number
		# is the part after the decimal, and needs to be padded correctly.
		# Note that have_decimal is one more than the number of digits after the decimal.
		for _ in range(have_decimal, 3):
			number *= 10 # Replace missing trailing zeroes
		number += integer * 100
	# TODO: Are there any other units that matter? "Cups" is //=2 , but are single cups distinguishable?
	if show_unit:
		print(post_number)
		for slice in post_number:
			print(f"{slice:013b}")
	# Full check: See if it has mL after the number
	#if len(post_number) >= len(mL) and number % 50 == 0:
	#	matches = sum(s1 == s2 for s1, s2 in zip(mL, post_number))
	#	if matches > len(mL) / 2: number //= 50 # Yep, it's mL
	# Simplified check: if it's a multiple of 50, divide.
	if number % 50 == 0 and not have_decimal:
		number //= 50
	return number
# print(read_row(ImageGrab.grab(), 594, 159, 170, 1))
# print(read_row(ImageGrab.grab(), 984, 620, 50, assume_decimal=True))

cols = [594, 958]
rows = [159, 276, 393, 508]

def read_numbers(screen):
	ret = []
	for row in rows:
		ret.append([])
		for col in cols:
			ret[-1].append(read_row(screen, col, row, 170))
	return ret
#print(read_numbers(ImageGrab.grab()))

# Coordinates of the up and down buttons
buttonx = 200
upbutton = -10
downbutton = 20

def reset():
	screen = ImageGrab.grab()
	for y, row in zip(rows, read_numbers(screen)):
		for x, num in zip(cols, row):
			if num:
				subprocess.run(["xdotool", "mousemove", str(x + buttonx), str(y + downbutton)] + ["click", "1"] * num, check=True)

def rate():
	reset()
	time.sleep(0.25) # Let the last one finish
	baseimg = ImageGrab.grab()
	baseline = read_row(baseimg, 984, 620, 50, assume_decimal=True)
	pairs = {}
	items, xy = [], []
	saved_values = None
	# saved_values = [(589, 608, 659, 787, 1101, 788, 662, 616, 611, 641, 732, 960, 735, 650, 632, 663, 763, 1002, 1544, 2747, 1544), (589, 589, 590, 593, 600, 621, 674, 810, 1147, 1962, 1783, 2525, 1819, 2064, 1188, 826, 680, 623, 601, 593, 590), (589, 778, 1239, 984, 1144, 1793, 1054, 723, 577, 516, 495, 501, 542, 656, 937, 655, 539, 493, 476, 469, 467), (589, 589, 590, 593, 600, 621, 674, 810, 1147, 1962, 1783, 2525, 1819, 2064, 1188, 826, 680, 623, 601, 593, 590), (589, 778, 1239, 984, 1144, 1793, 1054, 723, 577, 516, 495, 501, 542, 656, 937, 655, 539, 493, 476, 469, 467), (589, 854, 1503, 854, 589, 483, 443, 427, 422, 420, 420, 420, 420, 423, 430, 448, 495, 615, 906, 615, 495), (589, 608, 659, 787, 1101, 788, 662, 616, 611, 641, 732, 960, 735, 650, 632, 663, 763, 1002, 1544, 2747, 1544), (589, 854, 1503, 854, 589, 483, 443, 427, 422, 420, 420, 420, 420, 423, 430, 448, 495, 615, 906, 615, 495)]
	for y in rows:
		for x in cols:
			if saved_values:
				values = saved_values.pop(0)
			else:
				if baseimg.getpixel((x, y))[0] == 102: continue # It's the 7th or 8th and hasn't been unlocked.
				values = [baseline]
				for _ in range(20):
					subprocess.run(["xdotool", "mousemove", str(x + buttonx), str(y + upbutton), "click", "1"], check=True)
					time.sleep(0.1)
					values.append(read_row(ImageGrab.grab(), 984, 620, 50, assume_decimal=True))
				subprocess.run(["xdotool", "mousemove", str(x + buttonx), str(y + downbutton)] + ["click", "1"] * 20, check=True)
				values = tuple(values)
			# Up to two of them may remain unpaired if there are only 6 unlocked.
			# With 7 unlocked, exactly one should remain unpaired, and with 8, none.
			if values in pairs: pairs[values] = (pairs[values][0], len(items))
			else: pairs[values] = (len(items), None)
			items.append(values)
			xy.append((x, y))
	# print(items) # Save the full list for faster iteration
	once = 0
	for idx, values in enumerate(items):
		a, b = pairs[values]
		if b is None:
			# It's unpaired. Find the single highest and report it.
			peak = max(range(21), key=lambda i: values[i])
			print("(unpaired, peak %d)" % peak)
			x, y = xy[idx]
			if peak: subprocess.run(["xdotool", "mousemove", str(x + buttonx), str(y + upbutton)] + ["click", "1"] * peak, check=True)
		elif a == idx:
			# Find the peaks. A peak is any index where the values on each side are lower than it,
			# pretending that the values beyond the ends are zero.
			peaks = []
			if values[0] > values[1]: peaks.append(0)
			for i in range(1, 20):
				if values[i-1] < values[i] > values[i+1]: peaks.append(i)
			if values[20] > values[19]: peaks.append(20)
			print(*peaks, "paired with", b + 1)
			if once == 2: continue
			if once == 1: once = 2
			# Ultimately, this search is an optimized version of "iterate A from 0 to 20, iterate B from 0 to 20, find the best".
			# It'd take a long time to brute-force 441 options, and we can do better.
			x1, y1 = xy[a]
			x2, y2 = xy[b]
			best = (0, 0); bestscore = baseline
			if "brute-force": # meh let's just brute force it.
				for A in range(21):
					for B in range(21):
						time.sleep(0.1)
						score = read_row(ImageGrab.grab(), 984, 620, 50, assume_decimal=True)
						if score > bestscore:
							best = (A, B); bestscore = score
						if B < 20: subprocess.run(["xdotool", "mousemove", str(x2 + buttonx), str(y2 + upbutton)] + ["click", "1"], check=True)
					subprocess.run(["xdotool", "mousemove", str(x2 + buttonx), str(y2 + downbutton)] + ["click", "1"] * 20, check=True)
					if A < 20: subprocess.run(["xdotool", "mousemove", str(x1 + buttonx), str(y1 + upbutton)] + ["click", "1"], check=True)
				subprocess.run(["xdotool", "mousemove", str(x1 + buttonx), str(y1 + downbutton)] + ["click", "1"] * 20, check=True)
			else:
				# Let's try being smarter. We already know what happens if we set one value to
				# its first peak; let's use that. (If (0,0) is better than other values, the
				# first peak WILL be 0, so this will be the same thing.)
				best = (peaks[0], 0); bestscore = values[peaks[0]]
				# And we know that nudging either side from there won't help, so let's not.
				# What if we set the other to the same peak?
				if peaks[0]:
					...
				# Actually, you know what? 150 seconds per pair isn't that bad after all. I'm lazy.
			print("Best:", best, bestscore)
			A, B = best
			if A: subprocess.run(["xdotool", "mousemove", str(x1 + buttonx), str(y1 + upbutton)] + ["click", "1"] * A, check=True)
			if B: subprocess.run(["xdotool", "mousemove", str(x2 + buttonx), str(y2 + upbutton)] + ["click", "1"] * B, check=True)
		else:
			print("Paired with", a + 1)

rate()
