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

-- TODO: Make this into a *template* and have Python actually prepopulate this.
-- Also record any leading silence on the track, and maybe trailing silence.
-- Then this script can lose the socket connection, lose the latency, and just
-- use prerecorded data to manage volumes.
file_volumes = { } -- Map a URI to its volume as returned by Python
leading_silence = { } -- Ditto for leading silence

function activate()
	vlc.msg.dbg("[AutoVol] Activated")
	input_changed()
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
	local vol = file_volumes[item:uri()]
	if vol then vlc.msg.dbg("Got volume: " .. vol) end
	-- Remember the file_volumes[] value for the previous and current
	-- Use the change between those values to adjust the volume, thus
	-- respecting any manual volume change.
	-- TODO: What if there's one track that we don't have data for?
	local skip = leading_silence[item:uri()]
	if skip then vlc.msg.dbg("Skip silence: " .. skip) end
end

function playing_changed(status)
	-- 2 is playing, 3 is paused, 4 is loading?? TODO: Find docs.
	-- Not needed for current setup but might be of interest
	vlc.msg.dbg("[AutoVol] Playing changed to " .. status)
end

function meta_changed()
	-- Probably not interesting
end
