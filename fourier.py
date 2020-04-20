import wave
import numpy as np
import matplotlib.pylab as plt
from scipy.fft import fft, ifft
N = 600
T = 1.0 / 800.0
x = np.linspace(0.0, N*T, N)
xf = np.linspace(0.0, 1.0/(2.0*T), N/2)

x2pi = 2.0*np.pi*x

def graph(x, y, ofs):
	N = len(y)
	# plt.plot(x, y + ofs)
	fourier = fft(y) # Has two peaks for every peak, and troughs next to the peaks
	fourier = fourier[:N//2] # Look at just the first half of the graph
	fourier = np.abs(fourier) # Show tidy peaks where the interesting stuff is
	fourier = 4.0/N * fourier # Rescale to allow both the original and the transform to be readable
	plt.plot(x[::2], fourier + ofs)

def graph_audio(fn, ofs):
	with wave.open(fn) as wav:
		print("Channels:", wav.getnchannels())
		print("Sample width:", wav.getsampwidth())
		print("Frame rate:", wav.getframerate())
		print("Num frames:", wav.getnframes())
		dtype = {1: np.int8, 2: np.int16, 4: np.int32}[wav.getsampwidth()]
		frames = np.frombuffer(wav.readframes(wav.getnframes()), dtype=dtype)
		print("Got frames:", len(frames))
		x = np.linspace(0.0, len(frames) / wav.getsampwidth(), len(frames))
		graph(x, frames, ofs)

graph_audio("../tmp/wavs/a220.wav", -20000)
graph_audio("../tmp/wavs/c275.wav", -10000)
graph_audio("../tmp/wavs/chord.wav", 0)
graph_audio("../tmp/wavs/e330.wav", +10000)
graph_audio("../tmp/wavs/a440.wav", +20000)
# graph(x, np.sin(x2pi * 50), 1)
# graph(x, np.sin(x2pi * 75), -1)
# graph(x, np.sin(x2pi * 50) + np.sin(x2pi * 75), 0)
#plt.plot(x, fft(np.sin(x2pi * 50)))
#plt.plot(x, np.sin(x * 3 / (500/np.pi)))
#plt.plot(x, np.sin(x * 3 / (500/np.pi)) + np.sin(x * 4 / (500/np.pi)))
plt.xlabel('Angle [rad]')
plt.ylabel('sin(x)')
plt.axis('tight')
plt.show()
