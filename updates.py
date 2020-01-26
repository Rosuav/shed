#!/usr/bin/python3
# requires system Python and the python3-apt package
from collections import OrderedDict # Starting with Python 3.7, we could just use vanilla dicts
import apt # ImportError? apt install python3-apt

def describe(pkg):
	# Python 3.7 equivalent:
	# return {"Name": pkg.name, "Installed": pkg.installed.version, "Candidate": pkg.candidate.version}
	return OrderedDict((("Name", pkg.name), ("Current", pkg.installed.version), ("Target", pkg.candidate.version)))

def show_packages(scr, upgrades, auto):
	def print(s="", *args):
		scr.addstr(str(s) + "\n", *args)
	desc = [describe(pkg) for pkg in upgrades]
	widths = OrderedDict((x, len(x)) for x in desc[0]) # Start with header widths
	for d in desc:
		for col in d:
			widths[col] = max(widths[col], len(d[col]))
	fmt = "[ ] " + "  ".join("%%-%ds" % col for col in widths.values())
	print(fmt % tuple(widths), curses.A_BOLD)
	print("--- " + "  ".join("-" * col for col in widths.values()))
	# TODO: Repeat this any time there's a resize
	# TODO: Also adjust for insufficient width?
	height, _ = scr.getmaxyx()
	perpage = min(height - 8, len(upgrades))
	scr.move(perpage + 2, 0)
	print()
	if auto: print("Plus %d auto-installed packages." % auto)
	print("Select packages to upgrade, then Enter to apply.")
	print("Press I for more info on a package [TODO]")
	pkg = 0
	action = [" "] * len(upgrades)
	lastpage = None
	while True:
		pagestart = pkg - pkg % perpage
		if pagestart != lastpage:
			lastpage = pagestart
			# Update (only if the page has changed)
			for i, d in enumerate(desc[pagestart : pagestart + perpage]):
				scr.addstr(i + 2, 0, fmt % tuple(d.values()))
			# Erase any spare space
			for i in range(i + 1, perpage):
				# Is this the best way to clear a line??
				scr.move(i + 2, 0)
				scr.clrtoeol()
			scr.setscrreg(2, perpage + 4)

		scr.move((pkg % perpage) + 2, 1)
		key = scr.getkey()
		if key == "Q" or key == "q": return []
		if key == "\n": break
		if key == "KEY_UP":   pkg = (pkg - 1) % len(upgrades)
		if key == "KEY_DOWN": pkg = (pkg + 1) % len(upgrades)
		if key == "KEY_MOUSE": TODO = curses.getmouse()
		if key == "KEY_RESIZE": TODO = ...
		if key == " ":
			action[pkg] = " " if action[pkg] == "I" else "I"
			scr.addstr(pkg + 2, 1, action[pkg])
		if key == "I" or key == "i":
			# TODO: Show a new window with package info
			# Show the from and to versions, optionally the changelog,
			# and ideally, the list of other packages that would be
			# upgraded along with this one (its out-of-date deps).
			pass
		# TODO: Have a way to mark auto from here? What about remove?
		# action[pkg] = "A"
		# Remove should be equiv of "apt --purge autoremove pkgname" if poss
		# (but ideally shouldn't disrupt other autoremovables).
		# scr.addstr(height - 2, 0, repr(key))
	return [pkg for pkg, ac in zip(upgrades, action) if ac == "I"]

def main():
	cache = apt.Cache()
	cache.open()
	upgrades = []
	auto = 0
	for pkg in cache:
		if not pkg.is_installed: continue # This is checking upgrades only
		if pkg.candidate == pkg.installed: continue # Already up-to-date
		if pkg.is_auto_installed:
			# Ignore (but summarize) autoinstalled packages
			auto += 1
			continue
		upgrades.append(pkg)
	if not upgrades:
		print("Everything up-to-date.")
		return

	global curses; import curses
	upgrades = curses.wrapper(show_packages, upgrades, auto)
	if not upgrades: return
	# if "simulate": print(upgrades); return
	for pkg in upgrades:
		pkg.mark_upgrade()
	# TODO: Show progress while it downloads? Not sure why the default progress
	# isn't being shown. Might need to subclass apt.progress.text.AcquireProgress?
	cache.commit()

if __name__ == "__main__":
	main()
