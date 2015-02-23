# Counterpart to senddir.py
import sys
if len(sys.argv)>1 and sys.argv[1]=="install":
	import os
	open("/etc/systemd/system/recvdir.service","w").write("""[Unit]
Description=Teleportation Arrivals

[Service]
# The user and path are derived at installation time
# from SUDO_USER and current working directory.
User=%s
WorkingDirectory=%s
ExecStart=%s %s
# If the network isn't available yet, restart until it is.
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
"""%(os.environ["SUDO_USER"],os.getcwd(),sys.executable,os.path.abspath(sys.argv[0])))
	print("Installed as recvdir.service.")
	exit()

# Main program continues below.
import socketserver

class Handler(socketserver.StreamRequestHandler):
	def handle(self):
		fn = self.rfile.readline().rstrip(b"\r\n").decode("UTF-8")
		with open(fn, "wb") as f:
			while "moar bytes!":
				chunk=self.rfile.read(8192)
				if not chunk: break
				f.write(chunk)
		print("Saved:",fn)

socketserver.TCPServer(("0.0.0.0",12345), Handler).serve_forever()
