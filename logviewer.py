#!/usr/bin/python3
# Interactive log file viewer
# Can exec to tail as a one-off, but there's no returning to the menu after
import subprocess
import os

while True:
	print("1. View DHCP logs")
	print("2. Tail DHCP logs")
	print("149. Shell (requires authentication)")
	print("0. Exit")
	cmd = input("Pick an action: ")
	if cmd == "1":
		subprocess.run(["journalctl", "-uisc-dhcp-server", "-n25", "--no-pager"])
	elif cmd == "2":
		os.execlp("journalctl", "journalctl", "-fuisc-dhcp-server")
		print("** Unable to exec to journalctl **")
	elif cmd == "3":
		print("Provide credentials to get shell access:")
		r = subprocess.run(["sudo", "-v"])
		if r.returncode: continue # Assume sudo already printed an error
		# Note that this will cause sudo to cache the credentials,
		# granting passwordless sudo for the next fifteen minutes (or
		# whatever the sysadmin has configured).
		os.execlp("/bin/bash", "bash")
		print("** Unable to exec to bash **")
	elif cmd == "0":
		break
	else:
		print("Unrecognized option.")
