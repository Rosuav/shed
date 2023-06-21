-- Install by symlinking into ~/.local/share/vlc/lua/extensions or equivalent
-- Fade out music after the next OBS scene change
-- Activate this extension to arm the plugin; it will autodeploy
-- the next time you change scenes.

HOST = "192.168.0.19"
PORT = 4455
PASSWORD = "correct-horse-battery-staple"
sock = nil
local pollfds = {}
buf = ""
json = require("dkjson")

function descriptor()
	return { 
		title = "&Fade on next OBS scene change",
		version = "0.1",
		author = "Rosuav",
		capabilities = { },
	}
end

-- https://github.com/MaHuJa/CC-scripts/blob/master/sha256.lua
-- Tweaked to remove the need for setmetatable() which probably comes at a steep performance
-- penalty (no memoization), but this is only for initial authentication handshake

-- From http://pastebin.com/gsFrNjbt linked from http://www.computercraft.info/forums2/index.php?/topic/8169-sha-256-in-pure-lua/

--  Adaptation of the Secure Hashing Algorithm (SHA-244/256)
--  Found Here: http://lua-users.org/wiki/SecureHashAlgorithm
--  Using an adapted version of the bit library
--  Found Here: https://bitbucket.org/Boolsheet/bslf/src/1ee664885805/bit.lua

local MOD = 2^32
local MODM = MOD-1
local function make_bitop_uncached(t, m)
	local function bitop(a, b)
		local res,p = 0,1
		while a ~= 0 and b ~= 0 do
			local am, bm = a % m, b % m
			res = res + t[am][bm] * p
			a = (a - am) / m
			b = (b - bm) / m
			p = p*m
		end
		res = res + (a + b) * p
		return res
	end
	return bitop
end

local bxor1 = make_bitop_uncached({[0] = {[0] = 0,[1] = 1}, [1] = {[0] = 1, [1] = 0}}, 2)

local function bxor(a, b, c, ...)
	local z = nil
	if b then
		a = a % MOD
		b = b % MOD
		z = bxor1(a, b)
		if c then z = bxor(z, c, ...) end
		return z
	elseif a then return a % MOD
	else return 0 end
end

local function band(a, b, c, ...)
	local z
	if b then
		a = a % MOD
		b = b % MOD
		z = ((a + b) - bxor1(a,b)) / 2
		if c then z = bit32_band(z, c, ...) end
		return z
	elseif a then return a % MOD
	else return MODM end
end

local function bnot(x) return (-1 - x) % MOD end

local function rshift1(a, disp)
	if disp < 0 then return lshift(a,-disp) end
	return math.floor(a % 2 ^ 32 / 2 ^ disp)
end

local function rshift(x, disp)
	if disp > 31 or disp < -31 then return 0 end
	return rshift1(x % MOD, disp)
end

local function lshift(a, disp)
	if disp < 0 then return rshift(a,-disp) end 
	return (a * 2 ^ disp) % 2 ^ 32
end

local function rrotate(x, disp)
    x = x % MOD
    disp = disp % 32
    local low = band(x, 2 ^ disp - 1)
    return rshift(x, disp) + lshift(low, 32 - disp)
end

local k = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
	0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
	0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
	0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
	0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
	0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function str2hexa(s)
	return (string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end))
end

local function num2s(l, n)
	local s = ""
	for i = 1, n do
		local rem = l % 256
		s = string.char(rem) .. s
		l = (l - rem) / 256
	end
	return s
end

local function s232num(s, i)
	local n = 0
	for i = i, i + 3 do n = n*256 + string.byte(s, i) end
	return n
end

local function preproc(msg, len)
	local extra = 64 - ((len + 9) % 64)
	len = num2s(8 * len, 8)
	msg = msg .. "\128" .. string.rep("\0", extra) .. len
	assert(#msg % 64 == 0)
	return msg
end

local function initH256(H)
	H[1] = 0x6a09e667
	H[2] = 0xbb67ae85
	H[3] = 0x3c6ef372
	H[4] = 0xa54ff53a
	H[5] = 0x510e527f
	H[6] = 0x9b05688c
	H[7] = 0x1f83d9ab
	H[8] = 0x5be0cd19
	return H
end

local function digestblock(msg, i, H)
	local w = {}
	for j = 1, 16 do w[j] = s232num(msg, i + (j - 1)*4) end
	for j = 17, 64 do
		local v = w[j - 15]
		local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
		v = w[j - 2]
		w[j] = w[j - 16] + s0 + w[j - 7] + bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
	end

	local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
	for i = 1, 64 do
		local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
		local maj = bxor(band(a, b), band(a, c), band(b, c))
		local t2 = s0 + maj
		local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
		local ch = bxor (band(e, f), band(bnot(e), g))
		local t1 = h + s1 + ch + k[i] + w[i]
		h, g, f, e, d, c, b, a = g, f, e, d + t1, c, b, a, t1 + t2
	end

	H[1] = band(H[1] + a)
	H[2] = band(H[2] + b)
	H[3] = band(H[3] + c)
	H[4] = band(H[4] + d)
	H[5] = band(H[5] + e)
	H[6] = band(H[6] + f)
	H[7] = band(H[7] + g)
	H[8] = band(H[8] + h)
end

function sha256(msg)
	msg = preproc(msg, #msg)
	local H = initH256({})
	for i = 1, #msg, 64 do digestblock(msg, i, H) end
	return str2hexa(num2s(H[1], 4) .. num2s(H[2], 4) .. num2s(H[3], 4) .. num2s(H[4], 4) ..
		num2s(H[5], 4) .. num2s(H[6], 4) .. num2s(H[7], 4) .. num2s(H[8], 4))
end

-- CJA 20230621: Encode directly to base64
local BASE64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64_6(n)
	-- Helper: encode one single 6-bit number into base 64
	return string.sub(BASE64, n + 1, n + 1)
end
local function base64_30(n)
	-- Helper: encode five 6-bit numbers into base 64
	return (base64_6(rshift(n, 24) % 64) ..
		base64_6(rshift(n, 18) % 64) ..
		base64_6(rshift(n, 12) % 64) ..
		base64_6(rshift(n, 6) % 64) ..
		base64_6(n % 64))
end

function sha256_base64(msg)
	msg = preproc(msg, #msg)
	local H = initH256({})
	for i = 1, #msg, 64 do digestblock(msg, i, H) end
	local b64 = (
		-- Three bytes become four base 64 units. That means that:
		-- Three 32-bit words become three 30-bit words plus a 6-bit unit.
		base64_30(rshift(H[1], 2)) ..
		base64_30(lshift(H[1] % 4, 28) + rshift(H[2], 4)) ..
		base64_30(lshift(H[2] % 16, 26) + rshift(H[3], 6)) ..
		base64_6(H[3] % 64) ..
		base64_30(rshift(H[4], 2)) ..
		base64_30(lshift(H[4] % 4, 28) + rshift(H[5], 4)) ..
		base64_30(lshift(H[5] % 16, 26) + rshift(H[6], 6)) ..
		base64_6(H[6] % 64) ..
		-- We have a total of eight 32-bit words, so now we have to encode
		-- two 32-bit words into two 30-bit words plus a 4-bit unit.
		base64_30(rshift(H[7], 2)) ..
		base64_30(lshift(H[7] % 4, 28) + rshift(H[8], 4)) ..
		base64_6(lshift(H[8] % 16, 2)) .. '=')
	return b64
end

function read(n)
	while #buf < n do
		vlc.net.poll(pollfds)
		local chunk = vlc.net.recv(sock, 2048)
		if chunk == "" then break end
		buf = buf .. chunk
		vlc.keep_alive()
	end
	local ret = string.sub(buf, 0, n)
	buf = string.sub(buf, n + 1)
	return ret
end

function activate()
	vlc.msg.dbg("[FadeMusic] Activated")
	sock = vlc.net.connect_tcp(HOST, PORT)
	vlc.msg.dbg("[FadeMusic] Sock is " .. sock)
	vlc.net.send(sock, "GET / HTTP/1.1\r\nHost: OBS\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: asdf\r\nSec-WebSocket-Version: 13\r\n\r\n")
	pollfds[sock] = vlc.net.POLLIN
	while not string.find(buf, "\r\n\r\n") do
		vlc.net.poll(pollfds)
		local chunk = vlc.net.recv(sock, 2048)
		if chunk == "" then break end
		buf = buf .. chunk
		vlc.keep_alive()
	end
	buf = string.sub(buf, string.find(buf, "\r\n\r\n") + 4)
	-- Okay, headers parsed. We really should look at those and see if the connection
	-- succeeded, but whatevs.

	local orig_vol = nil
	local delaymsg = json.encode({op = 8, d = {requestId = "delay", requests = {{
		requestType = "Sleep",
		requestData = {sleepMillis = 150} -- Speed of fade, ms per Ctrl-Down on the volume.
	}}}})
	-- Encode the length, and set the high bit to say we're masking.
	if #delaymsg > 125 then
		size = string.char(254, #delaymsg / 256, #delaymsg % 256)
	else
		size = string.char(#delaymsg + 128)
	end
	-- Client messages have to be masked. But we cheat and use an all-zeroes mask.
	-- That shouldn't be acceptable... it really shouldn't...
	delaymsg =  "\x81" .. size .. "\0\0\0\0" .. delaymsg
	-- Wait for a scene transition message. Note that, per VLC rules, we have to call
	-- vlc.keep_alive() every ten seconds or we will be killed. Be sure to subscribe
	-- to some sort of event that happens at least that frequently; for me, that's
	-- covered by an image slideshow that rotates every eight seconds (it's not even
	-- visible on scene but it's there!), but otherwise, consider subscribing to a
	-- heartbeat of some sort. Or use the same "batch with just a Sleep" trick as for
	-- the fade.
	while true do
		-- Read one websocket frame
		local header = read(2)
		-- Assume that it's a text frame (for now)
		-- string.byte(header) & 0x8F should equal 0x81
		local size = string.byte(header, 2)
		-- if size >= 128: raise ValueError("Masked frame from server")
		if size == 126 then
			local sz = read(2)
			size = string.byte(sz, 1) * 256 + string.byte(sz, 2)
		end
		-- elif size == 127: raise ValueError("64-bit length not supported")
		vlc.msg.dbg("[FadeMusic] Length " .. size)
		local frame = read(size)
		vlc.msg.dbg("[FadeMusic] Frame " .. frame)
		local msg = json.decode(frame)
		vlc.msg.dbg("[FadeMusic] Msg " .. msg.op)
		if msg.op == 0 then
			local secret = sha256_base64(PASSWORD .. msg.d.authentication.salt)
			local auth = sha256_base64(secret .. msg.d.authentication.challenge)
			vlc.msg.dbg(auth)
			local authmsg = {op = 1, d = {rpcVersion = 1, authentication = auth}}
			authmsg = json.encode(authmsg)
			-- TODO: Deduplicate
			if #authmsg > 125 then
				size = string.char(254, #authmsg / 256, #authmsg % 256)
			else
				size = string.char(#authmsg + 128)
			end
			vlc.net.send(sock, "\x81" .. size .. "\0\0\0\0" .. authmsg)
		end
		if msg.op == 5 and msg.d.eventType == "CurrentProgramSceneChanged" then
			vlc.msg.dbg("*** Scene change! Done! ***")
			-- Time to fade and pause the music.
			-- This is weird and stupid, but I'm actually using OBS to give me a timer.
			orig_vol = vlc.volume.get()
			if orig_vol == 0 then break end -- No fade needed
			vlc.volume.down()
			vlc.net.send(sock, delaymsg)
		end
		if msg.op == 9 and msg.d.requestId == "delay" then
			vlc.msg.dbg("Delays, delays")
			if vlc.volume.get() == 0 then break end -- Done fading (note that we delay after reaching 0 before pausing)
			vlc.volume.down()
			vlc.net.send(sock, delaymsg)
		end
	end
	if orig_vol ~= nil then
		vlc.playlist.pause()
		vlc.volume.set(orig_vol)
	end
	vlc.net.close(sock)
	vlc.deactivate()
end

function deactivate()
	vlc.msg.dbg("[FadeMusic] Deactivated")
end
