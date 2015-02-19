# Whenever a new file is created in a given directory, send it via TCP/IP to a
# target computer. The socket protocol is simple: send the file name (UTF-8
# encoded), then a \n, then the file contents, and then close the connection.
# Note that this protocol is *not* suitable for a Unix-to-Unix file transfer,
# as a Unix file name might contain a \n; but Windows disallows it, so we can
# save ourselves some trouble in the other end and use readline().
# Notification code derived from third example in Tim Golden's helpful page:
# http://timgolden.me.uk/python/win32_how_do_i/watch_directory_for_changes.html
# Copyright Tim Golden and Chris Angelico; licensed MIT.
# Tested using Python 3.4 but should work on other versions too.

import os
import sys
import time
import socket
import win32file
import win32con
import ntsecuritycon

path_to_watch = "."
HOST = "10.0.2.2" # The default IP for the host computer in a VirtualBox NAT network
PORT = 12345

hDir = win32file.CreateFile (
	path_to_watch,
	1, # FILE_LIST_DIRECTORY
	win32con.FILE_SHARE_READ | win32con.FILE_SHARE_WRITE | win32con.FILE_SHARE_DELETE,
	None,
	win32con.OPEN_EXISTING,
	win32con.FILE_FLAG_BACKUP_SEMANTICS,
	None
)
while "moar files":
	#
	# ReadDirectoryChangesW takes a previously-created
	# handle to a directory, a buffer size for results,
	# a flag to indicate whether to watch subtrees and
	# a filter of what changes to notify.
	#
	# NB Tim Juchcinski reports that he needed to up
	# the buffer size to be sure of picking up all
	# events when a large number of files were
	# deleted at once.
	#
	results = win32file.ReadDirectoryChangesW (
		hDir,
		1024,
		True,
		win32con.FILE_NOTIFY_CHANGE_FILE_NAME |	win32con.FILE_NOTIFY_CHANGE_DIR_NAME,
		None,
		None
	)
	for action, file in results:
		if action != 1: continue # We care only about new files.
		fn = os.path.join(path_to_watch, file)

		# I hate sleeping :( But the notification comes through as soon
		# as the file is created, and it might not yet be readable.
		# So we start with a short delay, then probe the file, and back
		# off until we succeed. Hopefully, this will be sufficient.
		# If the file isn't readable after the delay sequence is done,
		# it'll simply be left in the directory and never removed. You
		# can manually force it to be rechecked by moving it out and in
		# again, and as long as it's being moved within a drive, that
		# should be sufficiently quick as to be safe.
		for delay in (.1, 1, 5):
			time.sleep(delay)
			try:
				handle = win32file.CreateFile(
					fn,
					ntsecuritycon.FILE_GENERIC_READ,
					0, None, win32con.OPEN_EXISTING, 0, None
				)
			except win32file.error as exc:
				if exc.winerror == 32: continue # Keep waiting
				else: raise

			# If we get here, we should have a file open for reading.
			# So now, and only now, we establish a link to the server.
			if file=="T-888": # Terminator!
				# Don't send this to the server - terminate everything here instead.
				win32file.CloseHandle(handle)
				os.remove(fn)
				sys.exit(0)
			sock = socket.create_connection((HOST, PORT))

			basename = os.path.split(fn)[-1]
			sock.send(basename.encode("UTF-8") + b"\n")

			while "moar bytes":
				err, chunk = win32file.ReadFile(handle, 8192)
				if err or not chunk: break
				sock.send(chunk)

			sock.close()
			win32file.CloseHandle(handle)
			break # No more sleeping needed!

		# Delete the file when sent. Remove this line if not wanted.
		os.remove(fn)
