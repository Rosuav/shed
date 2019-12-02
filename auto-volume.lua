-- Install by symlinking into ~/.local/share/vlc/lua/extensions or equivalent
-- Will require the corresponding volume detection Python script to be running.

function descriptor()
	return { 
		title = "Auto-volume",
		version = "0.1",
		author = "Rosuav",
		capabilities = { "input-listener", "playing-listener" },
	}
end

sock = nil
line_buffer = ""
-- TODO: Make this into a *template* and have Python actually prepopulate this.
-- Also record any leading silence on the track, and maybe trailing silence.
-- Then this script can lose the socket connection, lose the latency, and just
-- use prerecorded data to manage volumes.
file_volumes = { } -- Map a URI to its volume as returned by Python

-- Read a line from the socket, buffering as needed
-- Ignores TELNET sequences. Returns nil if the socket is closed.
function read_line()
	if not sock then return nil end
	while true do
		local pos = string.find(line_buffer, "\n")
		if pos then
			local line = string.sub(line_buffer, 1, pos - 1)
			line_buffer = string.sub(line_buffer, pos + 1)
			vlc.msg.dbg("[AutoVol] Got line: " .. line)
			return line
		end
		local poll = {}
		poll[sock] = vlc.net.POLLIN
		local ret = vlc.net.poll(poll) -- without this call, the recv fails (???)
		vlc.msg.dbg("[AutoVol] Poll: " .. ret)
		local data = vlc.net.recv(sock, 1024)
		if not data then
			vlc.msg.dbg("[AutoVol] Got no data")
			sock = nil
			return nil
		end
		vlc.msg.dbg("[AutoVol] Got data: " .. data)
		line_buffer = line_buffer .. data
	end
end

function activate()
	vlc.msg.dbg("[AutoVol] Activated")
	-- Establish socket connection to Python
	-- TODO: What if it fails? We still get back an fd.
	sock = vlc.net.connect_tcp("localhost", 4321)
	vlc.msg.dbg("[AutoVol] Got socket: " .. sock)
	input_changed()
end

function deactivate()
	vlc.msg.dbg("[AutoVol] Deactivated")
	-- TODO: Detect if socket connection was already closed
	-- (or detect its closure and reset sock to nil)
	if sock then
		vlc.msg.dbg("[AutoVol] Closing socket: " .. sock)
		vlc.net.close(sock)
	end
end

function get_volume(uri)
	if not file_volumes[uri] then
		vlc.msg.dbg("[AutoVol] Fetching volume for " .. uri)
		vlc.net.send(sock, uri .. "\n")
		local l = read_line()
		while not file_volumes[uri] do
			vlc.msg.dbg("[AutoVol] Got volume line: " .. l)
			local u, v = string.match(l, "^(file://.*): (-?[0-9.])$")
			if u then
				vlc.msg.dbg("[AutoVol] Got match:")
				vlc.msg.dbg("[AutoVol] " .. u)
				vlc.msg.dbg("[AutoVol] " .. v)
				file_volumes[u] = v
			end
			l = read_line()
		end
	end
	return file_volumes[uri]
end

function input_changed()
	local item = vlc.input.item()
	if not item then
		vlc.msg.dbg("[AutoVol] No playlist item")
		return
	end
	vlc.msg.info("[AutoVol] Volume is " .. vlc.volume.get())
	vlc.msg.info("[AutoVol] Input changed to: " .. vlc.strings.decode_uri(item:uri()))
	local vol = get_volume(item:uri())
	if vol then vlc.msg.dbg("Got volume: " .. vol) end
	-- TODO: Ask a background Python script what the volume of
	-- this track is, and then auto-adjust volume.
	local playlist = vlc.playlist.get("playlist", false)
	local current = vlc.playlist.current()
	for _, item in ipairs(playlist.children) do
		if not item.flags.disabled then
			if current == "found it" then
				vlc.msg.info("[AutoVol] Next up is: " .. vlc.strings.decode_uri(item.path))
				return
			end
			if item.id == current then
				current = "found it"
			end
		end
	end
	if current == "found it" then
		vlc.msg.info("[AutoVol] On last track.")
	else
		vlc.msg.info("[AutoVol] Unknown current element: " .. current) -- ?? maybe on media lib?
	end
end

function playing_changed(status)
	-- 2 is playing, 3 is paused, 4 is loading?? TODO: Find docs.
	-- Not needed for current setup but might be of interest
	vlc.msg.dbg("[AutoVol] Playing changed to " .. status)
end

function meta_changed()
	-- Probably not interesting
end
