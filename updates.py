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
Press 'A' to mark a package as automatically installed.
Press 'R' to remove a package.
Press 'Q' to go back, or to quit the program.
"""

def show_packages(scr, cache, upgrades, auto):
	"""Returns True after making cache changes, or False to ignore and do nothing"""
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
	actions = [" "] * len(upgrades)
	lastheight = None
	popup = None
	def toggle(pkg, act):
		actions[pkg] = " " if actions[pkg] == act else act
		if pkg >= pagestart and pkg < pagestart + perpage:
			scr.addstr(pkg % perpage + 2, 1, actions[pkg])
	def make_popup(lines):
		nonlocal popup
		lines = lines[:height - 5] # Truncate if we don't have enough screen space
		popup = curses.newwin(len(lines) + 2, width - 4, 2, 2)
		popup.erase()
		popup.border()
		for i, line in enumerate(lines):
			if not isinstance(line, tuple): line = (line,)
			popup.addstr(i + 1, 1, line[0][:width - 6], *line[1:])
		popup.refresh()
		curses.curs_set(0)
	nonautodeps = []
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
			print("Press ? for help, or Q to quit without making any changes")
		pagestart = pkg - pkg % perpage
		if pagestart != lastpage:
			lastpage = pagestart
			# Update (only if the page has changed)
			for i, d in enumerate(desc[pagestart : pagestart + perpage]):
				scr.addstr(i + 2, 0, fmt % ((actions[pagestart + i],) + tuple(d.values())))
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
			if key in "Aa" and nonautodeps:
				for i, p in enumerate(upgrades):
					if p in nonautodeps:
						toggle(i, "A")
			if key in "?QqIiAa":
				popup = None
				nonautodeps = []
				scr.touchwin()
				scr.refresh()
				curses.curs_set(2)
			continue
		if key == "Q" or key == "q": return False
		if key == "\n": break
		if key == "KEY_UP":   pkg = (pkg - 1) % len(upgrades)
		if key == "KEY_DOWN": pkg = (pkg + 1) % len(upgrades)
		if key == "KEY_PPAGE": pkg = 0 if pkg < perpage else pkg - perpage
		if key == "KEY_NPAGE": pkg = len(upgrades) - 1 if pkg >= len(upgrades) - perpage else pkg + perpage
		if key == "KEY_MOUSE": TODO = curses.getmouse()
		if key == " ": toggle(pkg, "I")
		if key in "Aa": toggle(pkg, "A")
		if key in "Rr": toggle(pkg, "R")
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
			info = ["Upgrading %s from %s to %s" % (sel.fullname, sel.installed.version, sel.candidate.version)]
			try: sel.mark_upgrade()
			except apt.package.apt_pkg.Error as e:
				info.append("Unable to upgrade this package:")
				info.append(e.args[0])
			# Should I recognize packages by equality, identity, or name?
			changes = [p for p in cache.get_changes() if p != sel]
			if changes:
				info.append("")
				info.append("Additional packages to upgrade:")
				nonautodeps = []
				for p in changes:
					if p.installed == p.candidate: continue # For some reason, it sometimes marks "changes" that aren't changes at all.
					info.append("* %s from %s to %s" % (
						p.fullname,
						p.installed.version if p.installed else "(none)",
						p.candidate.version,
					))
					if not p.is_auto_installed:
						info[-1] = (info[-1], curses.A_BOLD)
						nonautodeps.append(p)
				if nonautodeps:
					info.append("")
					info.append(("%d dependencies were not auto-installed." % len(nonautodeps), curses.A_BOLD))
					info.append(("Press 'A' to mark those deps as auto.", curses.A_BOLD))
			# TODO: Disambiguate "A to mark my deps auto" from "A to mark me auto"?
			cache.clear()
			make_popup(info)
		if key in "Ww":
			# Similar info to "aptitude why".
			# Mark this package auto, mark it for deletion. See what needs to be
			# deleted. Filter to only those which are not auto. List those as the
			# deps of this package.
			# 1) Find out why this package was installed
			# 2) If this is a hard dep of a non-auto package (or of an auto package
			#    that is a hard dep of a non-auto package), this can be marked auto.
			# 3) If this is a Recommends/Suggests only, say which package.
			p = upgrades[pkg]._pkg # Is there a non-private way to find the underlying package?
			deps, recs, sugs = {}, {}, {}
			for dep in p.rev_depends_list:
				# Note: Using get_fullname() would be better than name, but it doesn't work on older apts
				n = dep.parent_pkg.name
				inst = cache[n]
				if not inst.installed: continue
				type = dep.dep_type_untranslated
				if type == "Depends":
					# Hard dependency. Definite reason to install something
					# TODO: Keep the most interesting, not the last seen, version?
					deps[n] = dep.parent_ver
				elif type == "Recommends":
					# Soft dependency. If there are no hard deps, then this would be
					# why the package was installed, but it shouldn't be marked auto.
					recs[n] = dep.parent_ver
				elif type == "Suggests":
					# Even softer dependency. As with Recommends but even more so.
					# A "Suggests" dep won't be shown unless there are no Deps *or*
					# Recs.
					sugs[n] = dep.parent_ver
			info = ["Why was %s installed?" % upgrades[pkg].name, ""]
			if deps: info.append("Depended on by:")
			elif recs: info.append("Recommended by:")
			elif sugs: info.append("Suggested by:")
			else: info.append("Presumably manual installation") # No deps.
			got_nonauto = False
			for dep in deps or recs or sugs: # Pick the highest-priority category only
				if not cache[dep].is_auto_installed:
					info.append(("* " + dep, curses.A_BOLD))
					got_nonauto = True
				else: info.append("* " + dep)
			# TODO: If got_nonauto is still False, trace up the chain of
			# hard deps until we find something that wasn't auto-installed.
			# So, for instance, if libfoo depends on libbar, libbar depends
			# on libspam, and I installed libspam-dev manually, report the
			# full chain. Possibly only do this for deps?
			make_popup(info)
		# scr.addstr(height - 2, 0, repr(key)); scr.clrtoeol()
	changes = False
	if "R" in actions:
		# Don't bother running through the packages (slow) if we aren't removing any
		already_auto_removable = {pkg.fullname for pkg in cache if pkg.is_auto_removable}
	for pkg, ac in zip(upgrades, actions):
		if ac != " ": changes = True
		if ac == "I": pkg.mark_upgrade()
		elif ac == "A": pkg.mark_auto()
		elif ac == "R": pkg.mark_delete(purge=True)
	if "R" in actions:
		# Remove should be equiv of "apt --purge autoremove pkgname" but
		# doesn't remove anything that was already autoremovable
		for pkg in cache:
			if pkg.is_auto_removable and pkg.fullname not in already_auto_removable:
				pkg.mark_delete(purge=True)
	return changes

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
	# if "simulate": print(cache.get_changes()); return # Note that this doesn't report on mark-auto actions
	# TODO: Show progress while it downloads? Not sure why the default progress
	# isn't being shown. Might need to subclass apt.progress.text.AcquireProgress?
	try: cache.commit()
	except apt.cache.LockFailedException:
		print("Cannot apply changes when not root.")
		for pkg in cache.get_changes():
			print("*", pkg.fullname) # TODO: Say what change was requested
		# TODO: Provide a 'sudo apt' command that would do the changes

if __name__ == "__main__":
	main()
