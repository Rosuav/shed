#!/usr/bin/python3
# requires system Python and the python3-apt package
from collections import OrderedDict # Starting with Python 3.7, we could just use vanilla dicts
import apt # ImportError? apt install python3-apt

def describe(pkg):
	# Python 3.7 equivalent:
	# return {"Name": pkg.name, "Installed": pkg.installed.version, "Candidate": pkg.candidate.version}
	return OrderedDict((("Name", pkg.name), ("Current", pkg.installed.version), ("Target", pkg.candidate.version)))

HELP_INFO = """Top-level package manager

This tool lists all packages that aren't marked auto, and have updates
available. Press Q at any time to exit without touching your system;
if you have no need to make changes, this script can be run without
root privileges.

Press Space to select or deselect a package for upgrade.
Press 'I' on any package to see more info about it.
Press 'A' to mark a package as automatically installed. (unimpl)
Press 'R' to remove a package. (unimpl)"""

def show_packages(scr, cache, upgrades, auto):
	def print(s="", *args):
		scr.addstr(str(s) + "\n", *args)
	desc = [describe(pkg) for pkg in upgrades]
	widths = OrderedDict((x, len(x)) for x in desc[0]) # Start with header widths
	for d in desc:
		for col in d:
			widths[col] = max(widths[col], len(d[col]))
	fmt = "[%s] " + "  ".join("%%-%ds" % col for col in widths.values())
	# print(fmt % ("*", *widths), curses.A_BOLD) # Python 3.5+
	print(fmt % (("*",) + tuple(widths)), curses.A_BOLD)
	print("--- " + "  ".join("-" * col for col in widths.values()))
	# TODO: Also adjust for insufficient width? Currently will quietly
	# truncate lines at the available width, which isn't bad if it's
	# just a character or two, but could be wasteful with long pkgnames.
	pkg = 0
	action = [" "] * len(upgrades)
	lastheight = None
	popup = None
	def toggle(pkg, act):
		action[pkg] = " " if action[pkg] == act else act
		scr.addstr(pkg % perpage + 2, 1, action[pkg])
	def make_popup(lines):
		nonlocal popup
		lines = lines[:height - 5] # Truncate if we don't have enough screen space
		popup = curses.newwin(len(lines) + 2, width - 4, 2, 2)
		popup.erase()
		popup.border()
		for i, line in enumerate(lines):
			popup.addstr(i + 1, 1, line[:width - 6])
		popup.refresh()
		curses.curs_set(0)
	while True:
		height, width = scr.getmaxyx() # Also used by make_popup()
		if height != lastheight:
			# Note that a resize event is sent through as a pseudo-key, so
			# this will trigger immediately, without waiting for the next
			# actual key.
			lastheight, lastpage = height, None
			scr.setscrreg(0, height - 1)
			perpage = min(height - 8, len(upgrades))
			scr.move(perpage + 2, 0)
			scr.clrtobot()
			print()
			if auto: print("Plus %d auto-installed packages." % auto)
			print("Select packages to upgrade, then Enter to apply.")
			print("Press ? for help, or I for more info on a package [TODO]")
		pagestart = pkg - pkg % perpage
		if pagestart != lastpage:
			lastpage = pagestart
			# Update (only if the page has changed)
			for i, d in enumerate(desc[pagestart : pagestart + perpage]):
				scr.addstr(i + 2, 0, fmt % ((action[pagestart + i],) + tuple(d.values())))
			# Erase any spare space, including the mandatory blank at the end
			for i in range(i + 1, perpage + 1):
				# Is this the best way to clear a line??
				scr.move(i + 2, 0)
				scr.clrtoeol()
			scr.setscrreg(2, perpage + 4)

		scr.move((pkg % perpage) + 2, 1)
		key = scr.getkey()
		if popup:
			# Restricted key handling when a popup is open
			if key in "?QqIi":
				popup = None
				scr.touchwin()
				scr.refresh()
				curses.curs_set(2)
			continue
		if key == "Q" or key == "q": return []
		if key == "\n": break
		if key == "KEY_UP":   pkg = (pkg - 1) % len(upgrades)
		if key == "KEY_DOWN": pkg = (pkg + 1) % len(upgrades)
		if key == "KEY_PPAGE": pkg = 0 if pkg < perpage else pkg - perpage
		if key == "KEY_NPAGE": pkg = len(upgrades) - 1 if pkg >= len(upgrades) - perpage else pkg + perpage
		if key == "KEY_MOUSE": TODO = curses.getmouse()
		if key == " ": toggle(pkg, "I")
		if key == "?":
			make_popup(HELP_INFO.split("\n"))
		if key == "I" or key == "i":
			# TODO: Show a new window with package info
			# Show the from and to versions, optionally the changelog,
			# and ideally, the list of other packages that would be
			# upgraded along with this one (its out-of-date deps).

			# Note: get_changelog() appears to be broken. No idea why.
			# Neither the default URI nor the hand-checked one below
			# work; not sure if it's failing to download or failing to
			# parse afterwards, but it gets no useful info.
			# http://packages.debian.org/changelogs/pool/%(src_section)s/%(prefix)s/%(src_pkg)s/%(src_pkg)s_%(src_ver)s/changelog
			# http://metadata.ftp-master.debian.org/changelogs/%(src_section)s/%(prefix)s/%(src_pkg)s/%(src_pkg)s_%(src_ver)s_changelog

			sel = upgrades[pkg]
			info = ["Upgrading %s from %s to %s" % (sel.fullname, sel.installed, sel.candidate)]
			try: sel.mark_upgrade()
			except apt.package.apt_pkg.Error as e:
				info.append("Unable to upgrade this package:")
				info.append(e.args[0])
			# Should I recognize packages by equality, identity, or name?
			changes = [p for p in cache.get_changes() if p != sel]
			if changes:
				info.append("")
				info.append("Additional packages to upgrade:")
				for p in changes:
					if p.installed == p.candidate: continue # For some reason, it sometimes marks "changes" that aren't changes at all.
					info.append("* %s [from %s to %s]" % (p.fullname, p.installed, p.candidate))
			cache.clear()
			make_popup(info)
		# TODO: Have a way to mark auto from here? What about remove?
		# action[pkg] = "A"
		# Remove should be equiv of "apt --purge autoremove pkgname" if poss
		# (but ideally shouldn't disrupt other autoremovables).
		# scr.addstr(height - 2, 0, repr(key)); scr.clrtoeol()
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
	upgrades = curses.wrapper(show_packages, cache, upgrades, auto)
	if not upgrades: return
	# if "simulate": print(upgrades); return
	for pkg in upgrades:
		pkg.mark_upgrade()
	# TODO: Show progress while it downloads? Not sure why the default progress
	# isn't being shown. Might need to subclass apt.progress.text.AcquireProgress?
	cache.commit()

if __name__ == "__main__":
	main()
