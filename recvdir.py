# Counterpart to senddir.py
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
