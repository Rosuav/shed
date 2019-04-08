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

function activate()
	vlc.msg.dbg("[AutoVol] Activated")
end

function deactivate()
	vlc.msg.dbg("[AutoVol] Deactivated")
end

function input_changed()
	local item = vlc.input.item()
	if not item then
		vlc.msg.dbg("[AutoVol] No playlist item")
		return
	end
	vlc.msg.info("[AutoVol] Volume is " .. vlc.volume.get())
	vlc.msg.info("[AutoVol] Input changed to: " .. vlc.strings.decode_uri(item:uri()))
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
	vlc.msg.info("[AutoVol] Playing changed to " .. status)
end

function meta_changed()
	-- Probably not interesting
end
