# USAGE: tail -Fn0 /var/www/logs/error.log | python3 oom_restart.py
import re
import subprocess
import time
last_restart = 0
try:
	while "more tail":
		line = input()
		if re.search("PHP Fatal error:  Allowed memory size of [0-9]+ bytes exhausted", line):
			# These fatals tend to come in bunches. Only restart once every 60 seconds, max.
			t = time.time()
			if t > last_restart + 60:
				last_restart = t
				print("PHP out of memory! Restarting.")
				subprocess.run(["systemctl", "restart", "php-fpm"])
except (KeyboardInterrupt, EOFError):
	# Normal termination
	pass
