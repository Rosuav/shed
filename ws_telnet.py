# Interactive WebSocket tinkerer
# Note that it is your responsibility to correctly encode your outgoing
# messages, eg properly-formatted JSON.
import asyncio
import os
import websockets # ImportError? pip install websockets

async def sender(sock):
	stdin = asyncio.StreamReader()
	asyncio.get_running_loop().add_reader(0, lambda: stdin.feed_data(os.read(0, 1)))
	while True:
		line = (await stdin.readline()).decode().strip()
		print("< " + line)
		await sock.send(line)

async def main():
	# FIXME: Get server from sys.argv
	async with websockets.connect("ws://localhost:4444/") as sock:
		asyncio.create_task(sender(sock))
		while True:
			line = await sock.recv()
			print("> " + line)

asyncio.run(main())
