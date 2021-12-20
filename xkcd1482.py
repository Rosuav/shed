# Read a WAV file and try to figure out what note is playing
import audioop
import bisect
import wave
import heapq
import clize # ImportError? pip install clize
import numpy as np
import matplotlib.pyplot as plt

def ms_to_srt(ms):
	hr = ms // 3600000; ms -= hr * 3600000
	min = ms // 60000; ms -= min * 60000
	sec = ms // 1000; ms -= sec * 1000
	return f"{hr:02d}:{min:02d}:{sec:02d},{ms:03d}"

# Basis for freq-to-note calculation: the octave containing A440
frequencies = [261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.0, 415.3, 440.0, 466.16, 493.88]
note_names = "C C# D Eb E F F# G Ab A Bb B".split()
def freq_to_note(hz):
	if hz < 20: return "(n/a)" # Extremely low frequencies probably don't have enough precision to judge
	octave = 4 # Middle C and above
	while hz < 254.285: # Midpoint between C and Bb below it
		octave -= 1
		hz *= 2
	while hz > 508.565: # Midpoint between Bb and C above it
		octave += 1
		hz /= 2
	# Pick the nearest reference frequency
	idx = bisect.bisect(frequencies, hz)
	if not idx: return "C" + str(octave)
	if idx == len(frequencies): return "Bb" + str(octave)
	# Otherwise it's between two values. Pick the one it's closer to.
	low, hi = frequencies[idx - 1], frequencies[idx]
	if hz - low < hi - hz: idx -= 1
	return note_names[idx] + str(octave)

@clize.run
def main(fn, *, probe_width=250, srt="", graph=False, anim="", anim_scale=0.0):
	"""Read through a WAV file and try to figure out what notes are playing

	fn: File to read

	probe_width: Sample the file every N milliseconds

	srt: File name to create a .srt file in

	graph: Show a full graph of the first data block

	anim: File name pattern to create animation (use eg %03d for frame number)

	anim_scale: Force the animation graph to be scaled to this value. Useful
	values depend on the probe width, but after a render, the peak is printed.
	If this is zero (the default), graphs will progressively rescale themselves
	until stability is achieved.
	"""
	# framerate is 1000/probe_width, glob is anim with * not a number, input is fn, output is whatever
	# ffmpeg -y -framerate 10 -pattern_type glob -i 'anim/*.png' -i 01_original.wav 01_original.mkv
	with wave.open(fn) as f:
		frm = f.readframes(f.getnframes())
		width = f.getsampwidth()
		rate = f.getframerate()
		if f.getnchannels() > 1: frm = audioop.tomono(frm, width, 0.5, 0.5)
	dtype = np.dtype("<i%d" % width)
	data = np.frombuffer(frm, dtype)
	chunksize = (rate * probe_width) // 1000 # Probe width is in ms, figure out frames per chunk
	freq_ratio = 1000 / probe_width # Multiply sample count by this to get Hz
	last = lastpeak = None
	freq = np.fft.fftfreq(chunksize)
	if srt: srt = open(srt, "w")
	max_peak = 0
	for pos in range(0, len(data), chunksize):
		if pos + chunksize > len(data): break # Not sure why but I'm having trouble with the final frame
		sp = np.fft.fft(data[pos:pos + chunksize])
		peak = np.argmax(abs(sp.real[:chunksize//2]))
		if abs(sp.real[peak]) < 100000: peak = 0 # Recognize "silence" when the peak isn't very strong
		max_peak = max(max_peak, abs(sp.real[peak]))
		if graph and peak:
			# Find the top ten magnitudes in the first segment with actual data
			# Note that we ignore the top half of the array and just get the indices
			# of the strongest peaks.
			peaks = heapq.nlargest(10, range(chunksize//2), key=lambda i: abs(sp.real[i]))
			print("pos", pos * 1000 // rate)
			for p in peaks: print(p, p * freq_ratio, freq_to_note(p * freq_ratio), sp.real[p])
			plt.plot(freq[:chunksize//2], abs(sp.real)[:chunksize//2])
			plt.show()
			graph = False
		if anim:
			ax = plt.gca()
			ax.set_ylim([0, max(max_peak, anim_scale)])
			plt.plot(freq[:chunksize//2], abs(sp.real)[:chunksize//2])
			plt.savefig(anim % (pos // chunksize))
			plt.close()
		# Find the single strongest frequency
		if peak != lastpeak:
			# If the freq hasn't changed, the note certainly hasn't. (Optimization only.)
			note = freq_to_note(peak * freq_ratio) if peak else None
			lastpeak = peak
		if note != last:
			# Every time it changes, show the time (in ms) and strongest frequency
			posms = pos * 1000 // rate
			print(posms, int(peak * freq_ratio), note, sp.real[peak])
			if srt and last is not None:
				print(ms_to_srt(lastpos), "-->", ms_to_srt(posms - probe_width//2), file=srt)
				print(last, file=srt)
				print(file=srt)
			last, lastpos = note, posms
	if srt:
		if last is not None:
			print(ms_to_srt(lastpos), "-->", ms_to_srt(posms - probe_width//2), file=srt)
			print(last, file=srt)
		srt.close()
	if anim_scale > 0: print("Strongest peak:", max_peak, "(%.2f%%)" % (max_peak / anim_scale * 100.0))
	else: print("Strongest peak:", max_peak)
