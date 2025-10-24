# Spawn VLC to show the camera, and give controls to adjust it.
# When VLC terminates, reset all settings that we changed and exit.
# On Ctrl-C or other termination, reset all settings and abandon VLC.
import curses
import fcntl
import signal
import subprocess
from linuxpy.video.device import Device

dev = "/dev/webcam_c615"

vlc = subprocess.Popen(["vlc", "v4l2://" + dev], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def ended(*a, **kw):
	# When the VLC process finishes, terminate ourselves cleanly.
	# NOTE: Even if we don't, it seems to crash something. Might need to guard elsewhere
	# against signals interrupting getkey().
	if vlc.poll() is not None:
		signal.raise_signal(signal.SIGINT)
signal.signal(signal.SIGCHLD, ended)

def main(stdscr):
	with Device(dev) as fd:
		# Rather than showing every control the camera has, reduce it to a select few.
		controls = [
			fd.controls.brightness,
			fd.controls.contrast,
			#fd.controls.focus_absolute, # Can only be set if autofocus is disabled
			#fd.controls.exposure_time_absolute, # Ditto autoexposure
		]
		initial_values = [ctrl.value for ctrl in controls]
		try:
			curctrl = 0
			while True:
				for i, ctrl in enumerate(controls):
					stdscr.addstr(i, 0, f"{'>' if curctrl == i else ' '} {ctrl.name:20} [{ctrl.value}]")
				stdscr.addstr(i + 2, 0, "Up/down to select, right/left to adjust, Q to quit: ")
				#stdscr.move(i + 3, 0)
				stdscr.refresh()
				key = stdscr.getkey()
				if key == "KEY_DOWN": curctrl = (curctrl + 1) % len(controls)
				elif key == "KEY_UP": curctrl = (curctrl + 1) % len(controls)
				elif key == "KEY_LEFT":  controls[curctrl].decrease()
				elif key == "KEY_RIGHT": controls[curctrl].increase()
				elif key == "q" or key == "Q": break
		finally:
			# Reset all settings when we're done.
			for ctrl, ctrl.value in zip(controls, initial_values): pass

try: curses.wrapper(main)
except KeyboardInterrupt: pass # Ctrl-C is a valid termination signal, either manually or from VLC ending
