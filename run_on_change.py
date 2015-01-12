# Demo: Run .py files whenever they get changed.
# Save a file, see the results straight away.
import pyinotify
import os
import subprocess
wm = pyinotify.WatchManager()
class Handler(pyinotify.ProcessEvent):
	def process_default(self,event):
		fn = event.pathname
		if not fn.endswith(".py"): return
		print("Running: "+fn)
		if os.access(fn, os.X_OK):
			# File is executable (presumably with a shebang).
			# Run it directly, thus allowing the shebang to choose
			# which Python interpreter to use.
			subprocess.Popen([fn])
		else:
			# File is not executable. Invoke it with a default set
			# of args. Recommendation: Include -tt in this, to have
			# a consistent check for indentation errors.
			subprocess.Popen(["python",fn])
notifier = pyinotify.Notifier(wm, Handler())
wm.add_watch(".", pyinotify.IN_CLOSE_WRITE)
notifier.loop()
