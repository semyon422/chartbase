local class = require("class")
local bit = require("bit")
local byte = require("byte")
local leb128 = require("leb128")
local _7z = require("7z")

---@alias osu.OsrEvent {[1]: integer, [2]: integer, [3]: integer, [4]: integer}

---@class osu.Osr
---@operator call: osu.Osr
---@field events osu.OsrEvent[]
local Osr = class()

local WIN_EPOCH = 621355968000000000

function Osr:new()
	self.mode = 3
	self.version = tonumber(os.date("%Y%m%d"))  -- yyyymmdd
	self.beatmap_hash = ""
	self.player_name = ""
	self.replay_hash = ""
	self._300 = 0
	self._100 = 0
	self._50 = 0
	self.gekis = 0  -- Max 300s in mania
	self.katus = 0  -- 200s in mania
	self.misses = 0
	self.score = 0
	self.combo = 0
	self.pfc = 0
	self.mods = 0
	self.life_bar_graph = ""
	self.timestamp = WIN_EPOCH  -- Windows ticks
	self.replay_length = 0
	self.comp_replay = ""
	self.uncomp_replay = ""
	self.lzma_props = string.char(93, 0, 0, 32, 0)
	self.online_score_id = 0
	self.additional_mod_info = nil  ---@type number?
end

local function read_string(b)
	local a = b:int8()
	if a == 0x00 then
		return ""
	end
	assert(a == 0x0b)

	local bytes, length = leb128.udec(b.pointer + b.offset)
	b:seek(b.offset + bytes)

	return b:string(length)
end

local function write_string(b, s)
	if s == "" then
		b:int8(0x00)
		return
	end
	b:int8(0x0b)

	local bytes = leb128.uenc(b.pointer, #s)
	b:seek(b.offset + bytes)

	b:fill(s)
end

---@param replay_data string
---@return osu.OsrEvent[]
local function decode_replay_events(replay_data)
	local events = {}
	for dt, x, y, km in replay_data:gmatch("([^,^|]+)|([^,^|]+)|([^,^|]+)|([^,^|]+),") do
		table.insert(events, {
			tonumber(dt),
			tonumber(x),
			tonumber(y),
			tonumber(km),
		})
	end
	return events
end

---@param events osu.OsrEvent[]
---@return string
local function encode_replay_events(events)
	local out = {}
	for i, e in ipairs(events) do
		out[i] = ("%s|%s|%s|%s,"):format(e[1], e[2], e[3], e[4])
	end
	return table.concat(out)
end

---@param s string
function Osr:decode(s)
	local b = byte.buffer(#s)
	b:fill(s):seek(0)

	self.mode = b:int8()
	self.version = b:int32_le()
	self.beatmap_hash = read_string(b)
	self.player_name = read_string(b)
	self.replay_hash = read_string(b)
	self._300 = b:int16_le()
	self._100 = b:int16_le()
	self._50 = b:int16_le()
	self.gekis = b:int16_le()
	self.katus = b:int16_le()
	self.misses = b:int16_le()
	self.score = b:int32_le()
	self.combo = b:int16_le()
	self.pfc = b:int8()
	self.mods = b:int32_le()
	self.life_bar_graph = read_string(b)
	self.timestamp = b:int64_le()

	local replay_length = b:int32_le()  ---@type integer
	local comp_replay = b:string(replay_length)  ---@type string
	local uncomp_replay, lzma_props = _7z.decode_s(comp_replay)
	self.lzma_props = lzma_props
	self.events = decode_replay_events(uncomp_replay)

	self.online_score_id = b:int64_le()
	if b.offset < b.size then
		self.additional_mod_info = b:double_le()  -- Target Practice accuracy
	end
end

---@return string
function Osr:encode()
	local b = byte.buffer(1024)  -- header buffer

	b:int8(self.mode)
	b:int32_le(self.version)
	write_string(b, self.beatmap_hash)
	write_string(b, self.player_name)
	write_string(b, self.replay_hash)
	b:int16_le(self._300)
	b:int16_le(self._100)
	b:int16_le(self._50)
	b:int16_le(self.gekis)
	b:int16_le(self.katus)
	b:int16_le(self.misses)
	b:int32_le(self.score)
	b:int16_le(self.combo)
	b:int8(self.pfc)
	b:int32_le(self.mods)
	write_string(b, self.life_bar_graph)
	b:int64_le(self.timestamp)

	local uncomp_replay = encode_replay_events(self.events)
	local comp_replay = _7z.encode_s(uncomp_replay, self.lzma_props)

	b:int32_le(#comp_replay)

	local replay_data_offset = b.offset  ---@type integer

	b:int64_le(self.online_score_id)
	if self.additional_mod_info then
		b:double_le(self.additional_mod_info)
	end

	local end_header_offset = b.offset  ---@type integer

	---@type string[]
	local out = {}

	b:seek(0)
	out[1] = b:string(replay_data_offset)
	out[2] = comp_replay
	b:seek(replay_data_offset)
	out[3] = b:string(end_header_offset - replay_data_offset)

	return table.concat(out)
end

---@return number
function Osr:getTimestamp()
	return (self.timestamp - WIN_EPOCH) / 1e7
end

---@return number
function Osr:setTimestamp(ts)
	return ts * 1e7 + WIN_EPOCH
end

function Osr:decodeManiaEvents()
	---@type {[1]: integer, [2]: integer, [3]: boolean}[]
	local mania_events = {}
	local i = 0
	local t = 0
	local prev_x = 0
	---@type boolean[]
	local keys = {}
	for _, e in ipairs(self.events) do
		local dt, x = e[1], e[2]
		if dt == -12345 then
			break
		end
		t = t + dt
		if x ~= prev_x then
			prev_x = x
			local key = 0
			while x > 0 do
				key = key + 1
				local pressed = bit.band(x, 1) ~= 0
				if pressed then
					keys[key] = true
					i = i + 1
					mania_events[i] = {t, key, true}
				end
				x = bit.rshift(x, 1)
			end
			for _key in pairs(keys) do
				if bit.band(x, bit.lshift(1, _key - 1)) == 0 then
					keys[_key] = nil
					i = i + 1
					mania_events[i] = {t, _key, false}
				end
			end
		end
	end
	return mania_events
end

---@param mania_events {[1]: integer, [2]: integer, [3]: boolean}[]
function Osr:encodeManiaEvents(mania_events)

end

return Osr
