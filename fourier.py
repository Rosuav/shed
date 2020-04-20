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
		dtype = {1: np.int8, 2: np.int16, 4: np.int32}[wav.getsampwidth()]
		frames = np.frombuffer(wav.readframes(wav.getnframes()), dtype=dtype)
		x = np.linspace(0.0, len(frames) / wav.getsampwidth(), len(frames))
		graph(x, frames, ofs)
		return frames, wav.getparams()

# Generate files with: sox -n -r 8000 a440.wav synth 5 sine 440
# However that makes an unreadable file, so instead:
# sox -n -r 8000 -t wav - synth 5 sine 440 | ffmpeg -i - a440.wav
graph_audio("../tmp/wavs/a220.wav", -20000)
graph_audio("../tmp/wavs/c275.wav", -10000)
graph_audio("../tmp/wavs/e330.wav", +10000)
graph_audio("../tmp/wavs/a440.wav", +20000)
# To create the combined chord:
# sox -m a220.wav c275.wav e330.wav a440.wav -t wav - | ffmpeg -i - chord.wav
data, params = graph_audio("../tmp/wavs/chord.wav", 0)

data, params = graph_audio("../tmp/wavs/mermaid.wav", 0)

pieces = []
for piece in np.array_split(data, len(data) // 1000):
	# In theory, this should give me back 75% of the samples but
	# following the same frequency pattern. It doesn't seem to
	# work though - it just pitches the audio down, same as any
	# naive resampling would do. What am I doing wrong?
	freqs = fft(piece)
	l = len(freqs)
	# Trim out the middle of the array, removing one eighth either
	# side of the middle. This should speed up the audio by 25%.
	# Trimming just the end of the array - eg by giving another
	# parameter to ifft() - has the same incorrect result of pitch
	# changing the audio. I don't get it.
	freqs = np.delete(freqs, slice(l * 3 // 8, l * 5 // 8))
	newpiece = ifft(freqs).astype(piece.dtype)
	pieces.append(newpiece)
	
synth_data = np.concatenate(pieces)
print(data[:32])
print(synth_data[:32])
with wave.open("../tmp/wavs/generated.wav", "wb") as wav:
	wav.setparams(params)
	wav.writeframes(synth_data)
graph_audio("../tmp/wavs/generated.wav", 2500)
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
