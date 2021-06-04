import math

SAMPLES_PER_SEC = 44100
BITS_PER_SAMPLE = 32
CHANNELS = 2
SECONDS = 1
SIGNED = True
NUM_SAMPLES = int(SAMPLES_PER_SEC * SECONDS) # Technically, the number of seconds is this over SAMPLES_PER_SEC, not the other way around

step = SAMPLES_PER_SEC / math.pi / 2
bit_depth = 1 << BITS_PER_SAMPLE
bytes_per_sample = BITS_PER_SAMPLE // 8
bytes_per_second = SAMPLES_PER_SEC * CHANNELS * bytes_per_sample
total_size = NUM_SAMPLES * CHANNELS * bytes_per_sample

header = b"".join((
	b"RIFF",
	(total_size + 36).to_bytes(4, "little"),
	b"WAVEfmt \20\0\0\0\1\0",
	CHANNELS.to_bytes(2, "little"),
	SAMPLES_PER_SEC.to_bytes(4, "little"),
	bytes_per_second.to_bytes(4, "little"),
	(BITS_PER_SAMPLE * CHANNELS // 8).to_bytes(2, "little"), # Bytes per sample
	BITS_PER_SAMPLE.to_bytes(2, "little"),
	b"data",
	total_size.to_bytes(4, "little"),
))
if len(header) != 44: raise Exception("Fallacy somewhere, I fancy!") # Header should always work out to 44 bytes

with open("playme.wav", "wb") as f:
	f.write(header)
	for i in range(NUM_SAMPLES):
		for c in range(CHANNELS):
			value = math.sin(i / step * 440) # Float, -1.0 to 1.0
			# In theory, I should be able to add other sine waves to it, and
			# combine them. I'm not sure why this isn't sounding right.
			# Ultimately, I want to be able to play with Fourier transforms,
			# decomposing and recomposing audio, but if I can't even get the
			# basic construction of a sine wave going, the rest won't work.
			if SIGNED and value < 0.0: value += 2.0
			if not SIGNED: value += 1.0
			# Now a float, 0.0 to 2.0
			value = int(value * bit_depth / 2)
			value = min(max(value, 0), bit_depth - 1)
			# Now an int within our given range
			f.write(value.to_bytes(bytes_per_sample, "little"))
