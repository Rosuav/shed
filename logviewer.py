#!/usr/bin/python3
# Interactive log file viewer
# Can exec to tail as a one-off, but there's no returning to the menu after
import subprocess
import os
import sys

commands = {}
def cmd(c):
	def deco(f):
		commands[c] = f
		return f
	return deco

@cmd("")
def menu():
	while True:
		print()
		print("1. View DHCP logs")
		print("2. Tail DHCP logs")
		print("149. Shell (requires authentication)")
		print("0. Exit")
		cmd = input("Pick an action: ")
		if cmd == "0":
			break
		if cmd in commands:
			commands[cmd]()
		else:
			print("Unrecognized option.")

@cmd("1")
@cmd("dhcp")
def view_dhcp():
	subprocess.run(["journalctl", "-uisc-dhcp-server", "-n25", "--no-pager"])

@cmd("2")
@cmd("dhcp -f")
@cmd("dhcp -F")
@cmd("dhcp --tail")
def tail_dhcp():
	os.execlp("journalctl", "journalctl", "-fuisc-dhcp-server")
	print("** Unable to exec to journalctl **")

@cmd("149")
@cmd("shell")
@cmd("-i")
def shell():
	print("Provide credentials to get shell access:")
	r = subprocess.run(["sudo", "-v"])
	if r.returncode: return # Assume sudo already printed an error
	# Note that this will cause sudo to cache the credentials,
	# granting passwordless sudo for the next fifteen minutes (or
	# whatever the sysadmin has configured).
	os.execlp("/bin/bash", "bash")
	print("** Unable to exec to bash **")

command = ""
try: command = sys.argv[sys.argv.index("-c") + 1]
except (ValueError, IndexError): pass
commands.get(command, commands[""])()
