#!/usr/bin/env python
import sys, os, tempfile, subprocess, time
if len(sys.argv)<2:
	print("Usage: %s dvdfile.iso" % sys.argv[0])
	print("Mounts the ISO, invokes VLC, and unmounts when done.")
	print("Requires sudo power to mount and unmount.")
	sys.exit(0)

mountpt = tempfile.mkdtemp("-dvdiso")
subprocess.call(["sudo","mount", "-o", "loop", sys.argv[1], mountpt])
subprocess.call(["vlc", "--play-and-exit", "dvdsimple://"+mountpt])
time.sleep(1) # I feel dirty doing this, but otherwise it seems the mount point is still busy.
subprocess.call(["sudo","umount", mountpt])
os.rmdir(mountpt)
