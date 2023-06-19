-- Install by symlinking into ~/.local/share/vlc/lua/extensions or equivalent
-- Fade out music after the next OBS scene change
-- Activate this extension to arm the plugin; it will autodeploy
-- the next time you change scenes.

HOST = "192.168.0.19"
PORT = 4444
PASSWORD = "correct-horse-battery-staple"
sock = nil

function descriptor()
	return { 
		title = "&Fade on next OBS scene change",
		version = "0.1",
		author = "Rosuav",
		capabilities = { },
	}
end

function activate()
	vlc.msg.dbg("[FadeMusic] Activated")
	sock = vlc.net.connect_tcp(HOST, PORT)
	vlc.msg.dbg("[FadeMusic] Sock is " .. sock)
	vlc.net.send(sock, "GET / HTTP/1.1\r\nHost: junk\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: asdf\r\nSec-WebSocket-Version: 13\r\n\r\n")
	local pollfds = {}
	pollfds[sock] = vlc.net.POLLIN
	vlc.net.poll(pollfds)
	local chunk = vlc.net.recv(sock, 2048)
	while chunk do
		vlc.keep_alive()
		vlc.msg.dbg(chunk)
		if string.find(chunk, "quit") then break end
		vlc.msg.dbg("[FadeMusic] Poll result: " .. vlc.net.poll(pollfds))
		chunk = vlc.net.recv(sock, 2048)
	end
	vlc.net.close(sock)
	vlc.deactivate()
end

function deactivate()
	vlc.msg.dbg("[FadeMusic] Deactivated")
end
