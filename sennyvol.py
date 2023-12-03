import alsaaudio
mixer = alsaaudio.Mixer("Headphone", cardindex=6)
print(mixer.getvolume())
mixer.close()
