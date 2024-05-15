local class = require("class")
local Sounds = require("osu.Sounds")

---@class osu.ProtoTempo
---@operator call: osu.ProtoTempo
---@field offset number
---@field tempo number
---@field signature number
local ProtoTempo = class()

---@class osu.ProtoVelocity
---@operator call: osu.ProtoVelocity
---@field offset number
---@field velocity number
local ProtoVelocity = class()

---@class osu.ProtoNote
---@operator call: osu.ProtoNote
---@field time number
---@field endTime number?
---@field column number
---@field is_double boolean
---@field sounds osu.Sound[]
---@field keysound boolean
local ProtoNote = class()

---@class osu.Osu
---@operator call: osu.Osu
---@field protoTempos osu.ProtoTempo[]
---@field protoVelocities osu.ProtoVelocity[]
---@field protoNotes osu.ProtoNote[]
---@field keymode number
local Osu = class()

---@param rawOsu osu.RawOsu
function Osu:new(rawOsu)
	self.rawOsu = rawOsu
	self.protoTempos = {}
	self.protoVelocities = {}
	self.protoNotes = {}
end

function Osu:decode()
	self.keymode = math.floor(self.rawOsu.sections.Difficulty.entries.CircleSize)
	self:decodeTimingPoints()
	self:decodeHitObjects()
end

function Osu:decodeTimingPoints()
	local points = self.rawOsu.sections.TimingPoints.points
	for _, p in ipairs(points) do
		p.timingChange = p.beatLength >= 0  -- real timingChange
	end

	---@type {[number]: {beatLength: number?, velocity: number?, signature: number?}}
	local filtered_points = {}

	---@type {[number]: boolean}, {[number]: boolean}
	local red_points, green_points = {}, {}

	for i = #points, 1, -1 do
		local p = points[i]
		local offset = p.offset
		if p.timingChange and not red_points[offset] then
			red_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {}
			filtered_points[offset].beatLength = p.beatLength
			filtered_points[offset].signature = p.signature
		elseif not p.timingChange and not green_points[offset] then
			green_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {}
			filtered_points[offset].velocity = math.min(math.max(0.1, math.abs(-100 / p.beatLength)), 10)
		end
	end

	for offset, fp in pairs(filtered_points) do
		local velocity = fp.velocity
		if fp.beatLength then
			table.insert(self.protoTempos, ProtoTempo({
				offset = offset,
				tempo = 60000 / fp.beatLength,
				signature = fp.signature,
			}))
			if not velocity then
				velocity = 1
			end
		end
		if velocity then
			table.insert(self.protoVelocities, ProtoVelocity({
				offset = offset,
				velocity = velocity,
			}))
		end
	end

	table.sort(self.protoTempos, function(a, b)
		return a.offset < b.offset
	end)
	table.sort(self.protoVelocities, function(a, b)
		return a.offset < b.offset
	end)
end

local function get_taiko_type(soundType)
	local column, is_double = 0, false
	if bit.band(soundType, 10) ~= 0 then  -- 2 | 8
		column = 2  -- kat
	else
		column = 1  -- don
	end
	is_double = bit.band(soundType, 4) ~= 0
	return column, is_double
end

function Osu:decodeHitObjects()
	local mode = tonumber(self.rawOsu.sections.General.entries.Mode)
	local keymode = self.keymode

	local points = self.rawOsu.sections.TimingPoints.points
	local p_i = 1
	local p = points[p_i]
	for _, obj in ipairs(self.rawOsu.sections.HitObjects.objects) do
		local next_p = points[p_i + 1]
		if next_p and obj.time >= next_p.offset then
			p = next_p
			p_i = p_i + 1
		end

		local column, is_double = 0, false
		if mode == 1 then
			column, is_double = get_taiko_type(obj.soundType)
		elseif mode == 3 then
			column = math.max(1, math.min(keymode, math.floor(obj.x / 512 * keymode + 1)))
		end

		local sounds, keysound = Sounds:decode(obj.soundType, obj, p)
		table.insert(self.protoNotes, {
			time = obj.time,
			endTime = obj.endTime,
			column = column,
			is_double = is_double,
			sounds = sounds,
			keysound = keysound,
		})
	end
end

return Osu
