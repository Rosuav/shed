"""
Make lots of files all identified in hex, but each one has a single non-hex letter in it.
When you "ls -S1 *X*" for each letter, the file names create a picture.
(-S will sort descending. Each file should be smaller than the one before it.)
(Which means that, after enough lines of image, the files will have negative size. Have fun.)

1A5FCCEA0561FB2XEBEA46E38F16BB79AD383F6D
2.....B40434C024711XB6F5AC9685D3926F37BB
2.71DC7AC79X576717E4EA33D85D7A678F5745F3
5....C5B72C2A6E210DE046BF4FEE21A3E9C2B71
5.2E65851DB030XD9563372F79BB26F9671613E3
5.....852D45X421BE04D231ADE46293D7B51EE1
7CF6952DB750D5CX887B0EDE5BFEDA7F3EA5CEAF
82E8D45A447D91FA7F6A87F937B2D66F1ECCFD01
8D648C280961C1DEAB7029F6F56D1CE5F016DC8B
9E15398B81BC3C31EDE7A2C4AF7A6E6A3099D5D0
AE23FFCA718060B9340D76D3338E79E299601216
BBBF5B0B9AD1236B99EDDF9AE27937A92940DF4B
C2D3BD4BE8733A1220DA38D03D5C9CC17725911B
C3E84E1D3FF6897DF15539A2CFEF988979CCB613
C7BA9561A86E906781FAE676C34E08ACB601B0B3
EA4262EF5B6BBCB881B3F258F14098AFF294DB61
EE46DAF2CEFAEDD4D65B74717C2FE3FFA83DBA7C
F728806BE2D3935A96D4B02F235A1C395F1E0ABC
F744EBA426017EF8F669D38303D536D6D99CA428
FA17F48B15DD17D6011AF3B64D3A28E353C89E3E

"""
import base64
import os
import random

img1 = """
.  .   .  .   .  .....  .   .  .....      ....     .    .....    .
.  .   .  .   .  .      .   .    .        .   .   . .     .     . .
.  ..  .  .   .  .      ..  .    .        .   .  .   .    .    .   .
.  . . .  .   .  ....   . . .    .        .   .  .....    .    .....
.  .  ..  .   .  .      .  ..    .        .   .  .   .    .    .   .
.  .   .   . .   .      .   .    .        .   .  .   .    .    .   .
.  .   .    .    .....  .   .    .        ....   .   .    .    .   .
""".split("\n")
img2 = """
 ...   .....  .   .  .....  ....     .    .....  .....    .....  .  .      .....
.   .  .      .   .  .      .   .   . .     .    .        .      .  .      .
.      .      ..  .  .      .   .  .   .    .    .        .      .  .      .
.      ....   . . .  ....   ....   .....    .    ....     ....   .  .      ....
.  ..  .      .  ..  .      . .    .   .    .    .        .      .  .      .
.   .  .      .   .  .      .  .   .   .    .    .        .      .  .      .
 ....  .....  .   .  .....  .   .  .   .    .    .....    .      .  .....  .....
""".split("\n")
img3 = """
....   .   .  .  .      ....        .       .      .   ...   .....
.   .  .   .  .  .      .   .      . .      .      .  .   .    .
.   .  .   .  .  .      .   .     .   .     .      .  .        .
....   .   .  .  .      .   .     .....     .      .   ...     .
.   .  .   .  .  .      .   .     .   .     .      .      .    .
.   .  .   .  .  .      .   .     .   .     .      .  .   .    .
....    ...   .  .....  ....      .   .     .....  .   ...     .
""".split("\n")
img4 = """
....   .....  .      .  .   .  .....  ....      .   .   ...    ...
.   .  .      .      .  .   .  .      .   .     .   .  .   .  .   .
.   .  .      .      .  .   .  .      .   .     .. ..  .      .
.   .  ....   .      .  .   .  ....   ....      . . .   ...   .
.   .  .      .      .  .   .  .      . .       .   .      .  .  ..
.   .  .      .      .   . .   .      .  .      .   .  .   .  .   .
....   .....  .....  .    .    .....  .   .     .   .   ...    ...
""".split("\n")

def generate_filenames(img, key, width=0):
	"""
	Generate a list of file names corresponding to the lines of image,
	with each one containing the given key.
	
	width will be calculated if not given or too small.
	"""
	needwidth = max(len(l) for l in img)
	if width < needwidth + 2:
		width = max(needwidth, 35) + 5
		if width % 2: width += 1 # Use an even number of hex digits to make them look like bytes
	filenames = []
	gutter = random.randrange(1, width - needwidth - 1) # Digits (characters) of left gutter. The rest is right gutter.
	for line in img:
		base = random.randbytes(width // 2).hex().upper()
		fn = list(base)
		spares = width
		for pos, chr in enumerate(line, gutter):
			if chr != ' ': spares -= 1; fn[pos] = chr
		# Insert the key on some current alphanumeric character (might be in the gutter)
		keypos = random.randrange(spares) + 1
		for pos, chr in enumerate(fn):
			if chr not in "0123456789ABCDEF": continue
			keypos -= 1
			if not keypos: break
		fn[pos] = key
		filenames.append("".join(fn))
	if len(set(filenames)) < len(filenames):
		# Oops, got a collision. Try again, with slightly longer file names
		# to reduce the chance of recollision. Note that collisions *across*
		# groups can't happen if they have unique keys, but just in case, the
		# file writing would bomb if it ran into that problem.
		return generate_filenames(img, key, width + 2)
	return filenames

def generate_files(filenames, pat):
	n = len(filenames)
	if not n: return
	sizes = random.sample(range(n, n * 100), n)
	sizes.sort(reverse=True)
	for fn, size in zip(filenames, sizes):
		print(f"%{len(str(len(filenames)))+3}d %s" % (size, fn))
		with open(pat % fn, "xb") as f:
			# Generate enough random data to get 'size' bytes of
			# base 64. We have to get *exactly* that many, in case
			# two files need to differ by only one byte (b64 can't
			# generate certain byte sizes).
			data = base64.b64encode(random.randbytes(4 * (size // 3) + 1))
			data = data.strip(b"=")[:size]
			f.write(data)

width = max(len(l) for l in img1 + img2 + img3 + img4) + 5
width += width % 2
os.makedirs("mess", exist_ok=True)
for fn in os.listdir("mess"):
	if fn.endswith(".pub"): os.unlink("mess/" + fn)
generate_files(generate_filenames(img1, key="W", width=width), "mess/%s.pub")
generate_files(generate_filenames(img2, key="X", width=width), "mess/%s.pub")
generate_files(generate_filenames(img3, key="Y", width=width), "mess/%s.pub")
generate_files(generate_filenames(img4, key="Z", width=width), "mess/%s.pub")
