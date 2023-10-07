# Make a JavaScript file available in a browser
# Runs a small server (not production-hardened or high performance)
# which serves a tiny predefined HTML file and a websocket. Whenever
# the specified JavaScript file changes, connected browser clients
# will be signalled to reload it.
import websockets # ImportError? pip install websockets
from watchdog.observers import Observer # ImportError? pip install watchdog
import asyncio
import collections
import hashlib
import http
import os.path
import sys

class HashLoader:
	def __init__(self, fn):
		self.filename = fn
		self.basename = os.path.basename(fn)
		self.fetch()
	def fetch(self):
		with open(self.filename, "rb") as f:
			self.content = f.read()
		self.hash = hashlib.md5(self.content).hexdigest() # sha256 is overkill for a simple cachebuster

sockets = []

async def connection(sock, path):
	print("CONNECTION", sock, path)
	sockets.append(sock)
	try:
		async for msg in sock:
			pass # No client-to-server messages currently needed
	except websockets.ConnectionClosedError:
		pass
	print("CONNECTION GONE", sock, path)
	sockets.remove(sock)

async def process_request(path, headers):
	"""Handle the basic HTTP requests needed to bootstrap everything"""
	if path == "/":
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
				socket.onmessage = (ev) => console.log("GOT UPDATE", ev.data);
			}
			connect();
		""")

async def main():
	async with websockets.serve(connection, "localhost", 8000, process_request=process_request):
		print("Ready and listening. Press Ctrl-C (maybe twice) to halt.")
		await asyncio.Future()

if len(sys.argv) < 2:
	print("USAGE: python3 %s filename.js" % sys.argv[0])
	sys.exit(1)

runjs = HashLoader(sys.argv[1])

asyncio.run(main())
