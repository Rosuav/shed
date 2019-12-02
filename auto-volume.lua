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

-- Map a URI to its volume as returned by Python. The "volume" is the average
-- dBFS as returned by pydub, multiplied by 2.56. The dBFS figure approximates
-- to a volume percentage variance - to get comparable perceived volume between
-- two files with dBFS of -30 and -20, set VLC's volume 10% lower on the louder
-- one. Here in the Lua plugin, we don't see volume as a percentage, but as a
-- value scaled to 256, so the dBFS values are all rescaled to this basis.
file_volumes = {
	-- [ volume-data-goes-here ] --
}
-- Similarly, map a URI to the number of microseconds of leading silence.
leading_silence = {
	-- [ silence-data-goes-here ] --
}

function activate()
	vlc.msg.dbg("[AutoVol] Activated")
	input_changed()
end

function deactivate()
	vlc.msg.dbg("[AutoVol] Deactivated")
end

last_volume = nil
function input_changed()
	local item = vlc.input.item()
	if not item then
		vlc.msg.dbg("[AutoVol] No playlist item")
		return
	end
	vlc.msg.info("[AutoVol] Volume is " .. vlc.volume.get())
	local fn = vlc.strings.decode_uri(item:uri())
	vlc.msg.info("[AutoVol] Input changed to: " .. fn)
	local vol = file_volumes[fn]
	-- TODO: What if there's one track that we don't have data for?
	if vol then
		vlc.msg.info("[AutoVol] Got volume: " .. vol)
		if last_volume ~= nil then
			vlc.msg.info("[AutoVol] Prev volume: " .. last_volume)
			vlc.volume.set(math.floor(vlc.volume.get() - vol + last_volume))
			vlc.msg.info("[AutoVol] Volume set to " .. vlc.volume.get())
		end
		last_volume = vol
	end
	local skip = leading_silence[fn]
	if skip then
		vlc.msg.info("[AutoVol] Skip silence: " .. skip)
		-- I think vlc.player.get_time() is the normal way to do this now, but
		-- it doesn't work in my version of VLC. Must be newer.
		local input = vlc.object.input()
		local time = vlc.var.get(input, "time")
		-- Skip leading silence if we're at the start (in the first 20ms)
		if time < 20000 then vlc.var.set(input, "time", skip) end
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
