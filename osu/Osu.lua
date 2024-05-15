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

---@alias osu.FilteredPoint {offset: number, beatLength: number?, velocity: number?, signature: number?}

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
	self:decodeHitObjects()
	self:decodeTimingPoints()
end

function Osu:decodeTimingPoints()
	local points = self.rawOsu.sections.TimingPoints.points
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
			filtered_points[offset].signature = p.signature
		elseif not p.timingChange and not green_points[offset] then
			green_points[offset] = true
			filtered_points[offset] = filtered_points[offset] or {offset = offset}
			filtered_points[offset].velocity = math.min(math.max(0.1, math.abs(-100 / p.beatLength)), 10)
		end
	end

	---@type osu.FilteredPoint[]
	local filtered_points_list = {}
	for _, fp in pairs(filtered_points) do
		table.insert(filtered_points_list, fp)
	end
	table.sort(filtered_points_list, function(a, b)
		return a.offset < b.offset
	end)
	self:updatePrimaryTempo(filtered_points_list)

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

---@param filtered_points osu.FilteredPoint[]
function Osu:updatePrimaryTempo(filtered_points)
	---@type {offset: number, beatLength: number}[]
	local tempo_points = {}
	for _, p in ipairs(filtered_points) do
		if p.beatLength then
			table.insert(tempo_points, {
				offset = p.offset,
				beatLength = p.beatLength,
			})
		end
	end

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

		self.maxTime = math.max(self.maxTime, obj.time)
	end
end

return Osu
