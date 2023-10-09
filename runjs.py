# Make a JavaScript file available in a browser
# Runs a small server (not production-hardened or high performance)
# which serves a tiny predefined HTML file and a websocket. Whenever
# the specified JavaScript file changes, connected browser clients
# will be signalled to reload it.
import websockets # ImportError? pip install websockets
import watchdog.events, watchdog.observers # ImportError? pip install watchdog
import argparse
import asyncio
import collections
import hashlib
import http
import os.path
import sys

class HashLoader(watchdog.events.FileSystemEventHandler):
	def __init__(self, fn, observer):
		self.filename = fn
		self.basename = os.path.basename(fn)
		self.fetch()
		observer.schedule(self, fn)
	def fetch(self):
		with open(self.filename, "rb") as f:
			self.content = f.read()
		self.hash = hashlib.md5(self.content).hexdigest() # sha256 is overkill for a simple cachebuster

	# Conceptually, we want to watch a single file for updates.
	# However, some editors may write to a separate file, then move it over the
	# original file. This may not work with this system, and would require the
	# notification of "move to this name".
	def on_modified(self, event):
		prevhash = self.hash
		self.fetch()
		if self.hash != prevhash: asyncio.run_coroutine_threadsafe(notify_update(self), loop)

sockets = []

async def connection(sock, path):
	sockets.append(sock)
	try:
		async for msg in sock:
			pass # No client-to-server messages currently needed
	except websockets.ConnectionClosedError:
		pass
	sockets.remove(sock)

async def notify_update(loader):
	print("File changed, sending update")
	for sock in sockets:
		await sock.send(loader.basename + "?" + loader.hash)

async def process_request(path, headers):
	"""Handle the basic HTTP requests needed to bootstrap everything"""
	if path == "/":
		print("Serving page.")
		# Note that in older Pythons, "\n".join() isn't allowed inside an f-string
		scripts = "\n".join(f'<script id=runjs_{js.basename.replace(".", "_")} src="/{js.basename}?{js.hash}" type=module></script>'
			for js in runjs.values())
		return (http.HTTPStatus.OK, {"Content-Type": "text/html"}, f"""<!doctype html>
			<html><head><title>RunJS</title>
				<script src="/runjs.js" type=module></script>
				{scripts}
			</head><body></body></html>""".encode())
	if path == "/runjs.js":
		return (http.HTTPStatus.OK, {"Content-Type": "text/javascript"}, b"""
			function connect() {
				let socket = new WebSocket("ws://" + window.location.host + "/ws");
				socket.onclose = () => setTimeout(connect, 2500);
				socket.onmessage = (ev) => {
					const id = "runjs_" + ev.data.split("?")[0].replace(".", "_");
					document.getElementById(id).remove();
					const script = document.createElement("script");
					script.type = "module";
					script.src = ev.data;
					script.id = id;
					document.head.append(script);
				};
			}
			connect();
		""")
	path = path.split("?")[0].removeprefix("/") # Ignore any querystring
	if path in runjs:
		return (http.HTTPStatus.OK, {"Content-Type": "text/javascript"}, runjs[path].content)

async def amain(args):
	global loop; loop = asyncio.get_running_loop()
	async with websockets.serve(connection, "localhost", args.port, process_request=process_request):
		print("Ready and listening on port %s. Press Ctrl-C (maybe twice) to halt." % args.port)
		await asyncio.Future()

def main():
	parser = argparse.ArgumentParser(description="RunJS - hot reload in browser")
	parser.add_argument("-p", "--port", help="Specify the port to run on", type=int, default=8000)
	parser.add_argument("files", nargs="+", help="JavaScript file to make available")
	args = parser.parse_args()
	# Start an observer for every file we're using
	observer = watchdog.observers.Observer()
	global runjs
	runjs = {os.path.basename(fn): HashLoader(fn, observer) for fn in args.files}
	observer.start()
	try: asyncio.run(amain(args))
	finally:
		observer.stop()
		observer.join()

if __name__ == "__main__":
	main()
