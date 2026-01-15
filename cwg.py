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

def read_row(screen, xpos, ypos, width):
	xmax = xpos + width
	xpos -= 1 # Allow the increment to happen at the top of the loop
	number = integer = 0
	have_decimal = 0
	post_number = []
	while xpos < xmax:
		xpos += 1 # This logically belongs at the bottom of the loop, but it's easier to use 'continue' if it's at the top
		stripe = read_stripe(screen, xpos, ypos)
		# Everything after the number could be a unit that matters to us
		if stripe or post_number: post_number.append(stripe)
		if stripe == 0: continue # Empty column, step forward
		if (stripe == 7168 # Decimal point?
			and read_stripe(screen, xpos + 1, ypos) == 7168
			and read_stripe(screen, xpos + 2, ypos) == 7168
			and read_stripe(screen, xpos + 3, ypos) == 0):
				integer = number
				number = 0
				have_decimal = 1
		likely = [0] * 10
		for i in range(CHAR_WIDTH):
			if i: stripe = read_stripe(screen, xpos + i, ypos)
			for digit, bitmap in enumerate(digits):
				if bitmap[i] == stripe: likely[digit] += 1
		# Pick the most likely. We assume that, most of the time, the bitmaps will exactly match;
		# in the event of something not quite matching, chances are a few of the stripes will still.
		digit, quality = max(enumerate(likely), key=lambda x: x[1])
		if quality < 4: continue # Bad match, slide forward a pixel and try again
		number = (number * 10) + digit
		if have_decimal: have_decimal += 1 # Count how many digits we get after the decimal
		xpos += CHAR_WIDTH
		post_number = []
	#for stripe in post_number:
	#	print(f"{stripe:013b}")
	if have_decimal:
		# Return fixed-place integer rather than float. The number
		# is the part after the decimal, and needs to be padded correctly.
		# Note that have_decimal is one more than the number of digits after the decimal.
		for _ in range(have_decimal, 3):
			number *= 10 # Replace missing trailing zeroes
		number += integer * 100
	return number, post_number
# print(read_row(ImageGrab.grab(), 984, 622, 50))

cols = [594, 958]
rows = [159, 276, 393]

def read_numbers(screen):
	ret = []
	for row in rows:
		ret.append([])
		for col in cols:
			number, unit = read_row(screen, col, row, 170)
			# TODO: Scan the unit to see if we need to scale the number down
			ret[-1].append(number)
	return ret

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
	baseline = read_row(ImageGrab.grab(), 984, 622, 50)[0]
	pairs = {}
	items, xy = [], []
	for y in rows:
		for x in cols:
			values = [baseline]
			for _ in range(20):
				subprocess.run(["xdotool", "mousemove", str(x + buttonx), str(y + upbutton), "click", "1"], check=True)
				time.sleep(0.1)
				values.append(read_row(ImageGrab.grab(), 984, 622, 50)[0])
			subprocess.run(["xdotool", "mousemove", str(x + buttonx), str(y + downbutton)] + ["click", "1"] * 20, check=True)
			values = tuple(values)
			# Up to two of them may remain unpaired
			if values in pairs: pairs[values] = (pairs[values][0], len(items))
			else: pairs[values] = (len(items), None)
			items.append(values)
			xy.append((x, y))
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
		else:
			print("Paired with", a + 1)

rate()
