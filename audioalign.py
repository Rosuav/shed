# Attempt to find out where two audio files align
import heapq
import time
import pydub, clize, numpy # ImportError? pip install pydub clize numpy

def hms_to_msec(hms):
	ret = 0
	hms, dot, dec = hms.partition(".")
	for part in hms.split(":"):
		ret = (ret * 60) + int(part)
	return ret * 1000 + int((dec + "000")[:3])

@clize.run
def find_alignment(bigfn, smallfn, basis, reference):
	"""Find potential alignment points for two audio files

	bigfn: Name of "big" audio file (eg a movie soundtrack)

	smallfn: Name of "small" audio file (eg one track from OST)

	basis: Approximate position in h:m:s format

	reference: Match point, h:m:s beyond the basis
	"""
	start_time = time.time()
	def report(msg): print(msg, time.time() - start_time)

	big = pydub.AudioSegment.from_wav(bigfn)
	sma = pydub.AudioSegment.from_wav(smallfn)
	for must_match in "sample_width channels frame_rate frame_width".split():
		if getattr(big, must_match) != getattr(sma, must_match):
			print("Audio files must have the same", must_match)
			print(bigfn, "has", getattr(big, must_match))
			print(smallfn, "has", getattr(sma, must_match))
			return 1

	report("Loaded.")
	hz = big.frame_rate
	dtype = numpy.dtype(">i2") # TODO: Derive this from the audio info
	basis = hms_to_msec(basis)
	reference = hms_to_msec(reference)
	print(basis, reference)
	smasamp = numpy.frombuffer(sma[reference - 500 : reference + 500].raw_data, dtype)
	bigsamp = numpy.frombuffer(big[basis + reference - 1000 : basis + reference + 2000].raw_data, dtype)
	best = []
	print(len(smasamp), len(bigsamp))
	# Need to upcast to int32 or double before squaring. Is there a faster way?
	smasamp = numpy.asfarray(smasamp)
	bigsamp = numpy.asfarray(bigsamp)
	# In theory, this is iterating from -hz to hz. In practice, that's too slow.
	# So what we do is check every Nth, pick the best, then refine those. This
	# isn't guaranteed perfect but it should be close. I think.
	stride = 64 # Probe every Nth sample
	keep_best = 32 # No need to keep all results, just the N best
	for syncpoint in range(big.channels * stride // 2, len(bigsamp) - len(smasamp), big.channels * stride):
		compare = bigsamp[syncpoint : syncpoint + len(smasamp)]
		d2 = sum((compare - smasamp) ** 2)
		heapq.heappush(best, (d2, syncpoint))
		best = best[:keep_best]
	# The first pass gave us the best N positions that are aligned on a 64-sample
	# boundary. In the second pass, we scan -32:+32 from each of them, for another
	# four thousand scans.
	report("First pass")
	for _, approx in best[:]:
		for ofs in range(1, stride // 2):
			for dir in (-big.channels, big.channels):
				syncpoint = approx + ofs * dir
				compare = bigsamp[syncpoint : syncpoint + len(smasamp)]
				d2 = sum((compare - smasamp) ** 2)
				heapq.heappush(best, (d2, syncpoint))
				best = best[:keep_best]
	for score, pos in best:
		ms = pos // big.channels * 1000 // big.frame_rate - 500 + basis
		sec = ms // 1000; ms %= 1000
		min = sec // 60; sec %= 60
		hr = min // 60; min %= 60
		print(f"{hr}:{min:02d}:{sec:02d}.{ms:03d}")
	report("Done.")
