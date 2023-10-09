# Make a JavaScript file available in a browser
# Runs a small server (not production-hardened or high performance)
# which serves a tiny predefined HTML file and a websocket. Whenever
# the specified JavaScript file changes, connected browser clients
# will be signalled to reload it.
import websockets # ImportError? pip install websockets
import watchdog.events, watchdog.observers # ImportError? pip install watchdog
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
		return (http.HTTPStatus.OK, {"Content-Type": "text/html"}, f"""<!doctype html>
			<html><head><title>RunJS</title>
				<script src="/runjs.js" type=module></script>
				<script id=runme src="/{runjs.basename}?{runjs.hash}" type=module></script>
			</head><body></body></html>""".encode())
	if path.startswith("/" + runjs.basename + "?"): # Ignore any querystring
		return (http.HTTPStatus.OK, {"Content-Type": "text/javascript"}, runjs.content)
	if path == "/runjs.js":
		return (http.HTTPStatus.OK, {"Content-Type": "text/javascript"}, b"""
			function connect() {
				let socket = new WebSocket("ws://" + window.location.host + "/ws");
				socket.onclose = () => setTimeout(connect, 2500);
				socket.onmessage = (ev) => {
					document.getElementById("runme").remove();
					const script = document.createElement("script");
					script.type = "module";
					script.src = ev.data;
					document.head.append(script);
				};
			}
			connect();
		""")

async def main():
	global loop; loop = asyncio.get_running_loop()
	port = 8000
	if (sys.argv[2] == "--port"):
		port = int(sys.argv[3])
	async with websockets.serve(connection, "localhost", port, process_request=process_request):
		print("Ready and listening on port %s. Press Ctrl-C (maybe twice) to halt." % port)
		await asyncio.Future()

if len(sys.argv) < 2:
	print("USAGE: python3 %s filename.js [--port 8001]" % sys.argv[0])
	sys.exit(1)

observer = watchdog.observers.Observer()
runjs = HashLoader(sys.argv[1], observer)
observer.start()

try: asyncio.run(main())
finally:
	observer.stop()
	observer.join()
