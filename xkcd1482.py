# Read a WAV file and try to figure out what note is playing
import audioop
import wave
import heapq
import clize # ImportError? pip install clize
import numpy as np
import matplotlib.pyplot as plt

@clize.run
def main(fn, probe_width=250):
	"""Read through a WAV file and try to figure out what notes are playing

	fn: File to read

	probe_width: Sample the file every N milliseconds
	"""
	with wave.open(fn) as f:
		frm = f.readframes(f.getnframes())
		width = f.getsampwidth()
		rate = f.getframerate()
		if f.getnchannels() > 1: frm = audioop.tomono(frm, width, 0.5, 0.5)
	dtype = np.dtype("<i%d" % width)
	data = np.frombuffer(frm, dtype)
	chunksize = (rate * probe_width) // 1000 # Probe width is in ms, figure out frames per chunk
	freq_ratio = 1000 / probe_width # Multiply sample count by this to get Hz
	print(chunksize)
	last = None
	freq = np.fft.fftfreq(chunksize)
	for pos in range(0, len(data), chunksize):
		sp = np.fft.fft(data[pos:pos + chunksize])
		if not pos:
			# Find the top ten magnitudes
			# Note that we ignore the top half of the array and just get the indices
			# of the strongest peaks.
			peaks = heapq.nlargest(10, range(chunksize//2), key=lambda i: abs(sp.real[i]))
			for p in peaks: print(p, p * freq_ratio, sp.real[p])
			plt.plot(freq, sp.real)
			plt.show()
		# Find the single strongest frequency
		peak = np.argmax(abs(sp.real[:chunksize//2])) * freq_ratio
		if peak != last:
			# Every time it changes, show the time (in ms) and strongest frequency
			print(pos * probe_width / 1000, int(peak))
			last = peak
