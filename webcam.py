# Spawn ["vlc", "v4l2://" + device]
# Provide some kind of UI to adjust v4l2 configs
# Can this be done by opening the device ourselves and fcntl'ing it?
# The UI might be text, GUI, or browser, whatever's convenient
# When VLC terminates, reset all settings that we changed and exit.
# On Ctrl-C or other termination, reset all settings and abandon VLC.
device = "/dev/webcam_c615"
