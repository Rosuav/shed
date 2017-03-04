# WebSocket throughput test

import os
import sys
import json
import time
import random
import asyncio
import itertools
from aiohttp import web, WSMsgType, ClientSession
try: from setproctitle import setproctitle
except ImportError: setproctitle = lambda t: None

# Load parameters
GAMES = 2500
PLAYERS_PER_GAME = 3
BYTES_PER_MOVE = 10240 # Client to server
BYTES_PER_UPDATE = 10240 # Server to client
SECONDS_BETWEEN_MOVES = 30 # per player

# Convenience
move_data = "<" * BYTES_PER_MOVE
update_data = ">" * BYTES_PER_UPDATE

stats = [0, 0, 0]
async def game_client(host, gameid, player):
	session = ClientSession()
	if ":" in host: host = "[" + host + "]" # IPv6 literal
	async with session.ws_connect("http://%s:8888/ws" % host) as ws:
		stats[0] += 1
		ws.send_json({"type": "login", "data": {"room": gameid, "name": str(player)}})
		async def make_moves():
			# Stagger the requests a bit
			tm = (time.time() - SECONDS_BETWEEN_MOVES +
				SECONDS_BETWEEN_MOVES // PLAYERS_PER_GAME * player +
				random.randrange(SECONDS_BETWEEN_MOVES // PLAYERS_PER_GAME)
			)
			while ws:
				tm += SECONDS_BETWEEN_MOVES
				delay = tm - time.time()
				if delay > 0:
					await asyncio.sleep(delay)
					if not ws: break
				stats[1] += 1
				ws.send_str(move_data)
		asyncio.ensure_future(make_moves())
		async for msg in ws:
			if msg.type == WSMsgType.TEXT:
				stats[2] += len(msg.data)
	ws = None

async def establish_clients(hosts):
	hosts = itertools.cycle(hosts)
	junk = hex(random.randrange(0x10000,0xfffff))[2:]
	for game in range(GAMES):
		gameid = "throughput" + junk + str(game)
		for player in range(PLAYERS_PER_GAME):
			asyncio.ensure_future(game_client(next(hosts), gameid, player))
	print("Sockets established. Ctrl-C to halt test.")
	tm = time.time()
	print("%6s %8s %8s (delta time)" % ("Socks", "Moves/s", "KBytes/s"))
	print("%6d %8.2f %8.2f <-- expected avg" % (
		# Expected sockets
		GAMES * PLAYERS_PER_GAME,
		# Expected moves/sec
		GAMES * PLAYERS_PER_GAME / SECONDS_BETWEEN_MOVES,
		# Expected KB/sec
		GAMES * PLAYERS_PER_GAME**2 * BYTES_PER_UPDATE / SECONDS_BETWEEN_MOVES / 1024,
	))
	while True:
		await asyncio.sleep(10)
		t = time.time(); delay = t - tm; tm = t
		print("%6s %8.2f %8.2f %.2f" % (stats[0], stats[1]/delay, stats[2]/delay/1024, delay))
		stats[1:] = 0, 0

if len(sys.argv) > 1:
	# Client
	setproctitle("ws client")
	loop = asyncio.get_event_loop()
	try: loop.run_until_complete(establish_clients(sys.argv[1:]))
	except KeyboardInterrupt: pass
	sys.exit()

setproctitle("ws server")
# Server. All above is hacks.

app = web.Application()
rooms = {}

class Room:
	def __init__(self, id):
		self.clients = []
		self.id = id; rooms[self.id] = self # floop
		# print("Creating new room %s [%d rooms]" % (self.id, len(rooms)))
		self.dying = None # Set to true when we run out of clients

	async def ws_login(self, ws, name, **xtra):
		if ws.username: return None
		ws.username = str(name)[:32]
		ws.send_str(update_data)

	async def ws_move(self, ws, **xtra):
		if not ws.username: return None
		return NotImplemented

	async def websocket(self, ws, login_data):
		ws.username = None
		self.dying = None # Whenever anyone joins, even if they disconnect fast, reset the death timer.
		self.clients.append(ws)
		await self.ws_login(ws, **login_data)

		async for msg in ws:
			# Ignore non-JSON messages
			if msg.type != WSMsgType.TEXT: continue
			data = msg.data
			if data == move_data:
				data = '{"type": "move", "data": {}}'
			try: msg = json.loads(data)
			except ValueError: continue
			if "type" not in msg or "data" not in msg: continue
			f = getattr(self, "ws_" + msg["type"], None)
			if not f: continue
			try:
				resp = await f(ws, **msg["data"])
			except asyncio.CancelledError:
				break
			except Exception as e:
				print("Exception in ws handler:")
				print(e)
				continue
			if resp is None: continue
			for client in self.clients:
				if resp is NotImplemented: client.send_str(update_data)
				else: client.send_json(resp)

		self.clients.remove(ws)
		await ws.close()
		if not self.clients:
			asyncio.ensure_future(self.die())
		return ws

	async def die(self):
		"""Destroy this room after a revive delay"""
		sentinel = object()
		self.dying = sentinel
		await asyncio.sleep(60)
		if self.dying is sentinel:
			# If it's not sentinel, we got revived. Maybe the
			# other connection is in dying mode, maybe not;
			# either way, we aren't in charge of death.
			assert not self.clients
			del rooms[self.id]
			# print("Room %s dead - %d rooms left" % (self.id, len(rooms)))

def route(url):
	def deco(f):
		app.router.add_get(url, f)
		return f
	return deco

@route("/")
async def home(req):
	return web.Response(text="Hello, world", content_type="text/plain")

@route("/ws")
async def websocket(req):
	ws = web.WebSocketResponse()
	await ws.prepare(req)
	async for msg in ws:
		if msg.type != WSMsgType.TEXT: continue
		try:
			msg = json.loads(msg.data)
			if msg["type"] != "login": continue
			room = msg["data"]["room"][:32]
			if room: break
		except (ValueError, KeyError, TypeError):
			# Any parsing error, just wait for another message
			continue
	else:
		# Something went wrong with the handshake. Kick
		# the client and let them reconnect.
		await ws.close()
		return ws
	if room not in rooms: Room(room)
	return await rooms[room].websocket(ws, msg["data"])

# Lifted from appension
async def serve_http(loop, port, sock=None):
	if sock:
		srv = await loop.create_server(app.make_handler(), sock=sock)
	else:
		srv = await loop.create_server(app.make_handler(), "", port)
		sock = srv.sockets[0]
	print("Listening on %s:%s" % sock.getsockname()[:2], file=sys.stderr)

def run(port=8080, sock=None):
	loop = asyncio.get_event_loop()
	loop.run_until_complete(serve_http(loop, port, sock))
	# TODO: Announce that we're "ready" in whatever way
	try: loop.run_forever()
	except KeyboardInterrupt: pass

if __name__ == '__main__':
	# Look for a socket provided by systemd
	sock = None
	try:
		pid = int(os.environ.get("LISTEN_PID", ""))
		fd_count = int(os.environ.get("LISTEN_FDS", ""))
	except ValueError:
		pid = fd_count = 0
	if pid == os.getpid() and fd_count >= 1:
		# The PID matches - we've been given at least one socket.
		# The sd_listen_fds docs say that they should start at FD 3.
		sock = socket.socket(fileno=3)
		print("Got %d socket(s)" % fd_count, file=sys.stderr)
	run(port=int(os.environ.get("PORT", "8888")), sock=sock)
