-- Install by symlinking into ~/.local/share/vlc/lua/extensions or equivalent

function descriptor()
	return { 
		title = "&Pause after this track",
		version = "0.1",
		author = "Rosuav",
		capabilities = { "input-listener", "playing-listener" },
	}
end

function activate()
	vlc.msg.dbg("[ThenPause] Activated")
end

function deactivate()
	vlc.msg.dbg("[ThenPause] Deactivated")
end

pause_next = false

function input_changed()
	-- Pausing in here doesn't seem to work - the track is in a
	-- loading/paused state. So we wait till we see it start to
	-- be actually played.
	pause_next = true
	vlc.msg.dbg("[ThenPause] Seen track change, will pause")
end

function playing_changed(status)
	vlc.msg.dbg("[ThenPause] Status is now " .. status)
	if pause_next then
		vlc.msg.info("[ThenPause] Pausing and deactivating.")
		vlc.playlist.pause()
		vlc.deactivate()
	end
end

function meta_changed()
end
