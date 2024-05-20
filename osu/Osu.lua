local class = require("class")
local Sounds = require("osu.Sounds")
local Barlines = require("osu.Barlines")

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
local ProtoNote = class()

---@class osu.FilteredPoint
---@field offset number
---@field beatLength number?
---@field velocity number?
---@field signature number?
---@field omitFirstBarLine boolean?

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
	self.keymode = math.floor(self.rawOsu.Difficulty.CircleSize)
	self:decodeHitObjects()
	self:decodeTimingPoints()
end

---@return string
function Osu:encode()
	return self.rawOsu:encode()
end

function Osu:decodeTimingPoints()
	local points = self.rawOsu.TimingPoints
	for _, p in ipairs(points) do
		p.timingChange = p.beatLength >= 0  -- real timingChange
	end

	---@type {[number]: osu.FilteredPoint}
	local filtered_points = {}

	---@type {[number]: boolean}, {[number]: boolean}
	local red_points, green_points = {}, {}

	for i = #points, 1, -1 do
		local p = points[i]
		local offset = p.offset
		if p.timingChange and not red_points[offset] then
			red_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {offset = offset}
			filtered_points[offset].beatLength = p.beatLength
			filtered_points[offset].signature = p.timeSignature
			filtered_points[offset].omitFirstBarLine = p.omitFirstBarLine
		elseif not p.timingChange and not green_points[offset] then
			green_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {offset = offset}
			filtered_points[offset].velocity = math.min(math.max(0.1, math.abs(-100 / p.beatLength)), 10)
		end
	end

	---@type osu.FilteredPoint[]
	local tempo_points = {}
	for _, p in pairs(filtered_points) do
		if p.beatLength then
			table.insert(tempo_points, p)
		end
	end
	table.sort(tempo_points, function(a, b)
		return a.offset < b.offset
	end)
	self:updatePrimaryTempo(tempo_points)
	self:decodeBarlines(tempo_points)

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

---@param tempo_points osu.FilteredPoint[]
function Osu:updatePrimaryTempo(tempo_points)
	local lastTime = self.maxTime
	local current_bl = 0

	---@type {[number]: number}
	local durations = {}

	local min_bl = math.huge
	local max_bl = -math.huge

	for i = #tempo_points, 1, -1 do
		local p = tempo_points[i]

		local beatLength = p.beatLength
		current_bl = beatLength
		min_bl = math.min(min_bl, current_bl)
		max_bl = math.max(max_bl, current_bl)

		if p.offset < lastTime then
			durations[current_bl] = (durations[current_bl] or 0) + (lastTime - (i == 1 and 0 or p.offset))
			lastTime = p.offset
		end
	end

	local longestDuration = 0
	local average = 0

	for beatLength, duration in pairs(durations) do
		if duration > longestDuration then
			longestDuration = duration
			average = beatLength
		end
	end

	if longestDuration == 0 then
		self.primaryBeatLength = 0
		self.primaryTempo = 0
		self.minTempo = 0
		self.maxTempo = 0
		return
	end

	self.primaryBeatLength = average
	self.primaryTempo = 60000 / average
	self.minTempo = 60000 / max_bl
	self.maxTempo = 60000 / min_bl
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
	self.maxTime = 0
	self.minTime = math.huge

	local mode = tonumber(self.rawOsu.General.Mode)
	local keymode = self.keymode

	local points = self.rawOsu.TimingPoints
	local p_i = 1
	local p = points[p_i]
	for _, obj in ipairs(self.rawOsu.HitObjects) do
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

		local sounds = Sounds:decode(obj.soundType, obj, p)
		table.insert(self.protoNotes, {
			time = obj.time,
			endTime = obj.endTime,
			column = column,
			is_double = is_double,
			sounds = sounds,
		})

		local time = obj.time
		local endTime = obj.endTime
		if time and time == time then  -- nan check
			self.maxTime = math.max(self.maxTime, time)
			self.minTime = math.min(self.minTime, time)
		end
		if endTime and endTime == endTime then  -- nan check
			self.maxTime = math.max(self.maxTime, endTime)
			self.minTime = math.min(self.minTime, endTime)
		end
	end
	if self.minTime == math.huge then
		self.minTime = 0
	end
end

---@param tempo_points osu.FilteredPoint[]
function Osu:decodeBarlines(tempo_points)
	self.barlines = Barlines:generate(tempo_points, self.maxTime)
end

return Osu
