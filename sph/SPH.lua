local class = require("class")
local Fraction = require("ncdk.Fraction")
local InputMode = require("ncdk.InputMode")

---@class sph.SPH
---@operator call: sph.SPH
local SPH = class()

function SPH:new()
	self.metadata = {}
	self.lines = {}
	self.intervals = {}
	self.velocities = {}
	self.expands = {}
	self.beatOffset = -1
	self.expandOffset = 0
	self.fraction = {0, 1}
end

---@param s string
function SPH:import(s)
	local headers = true
	for _, line in ipairs(s:split("\n")) do
		if line == "" and headers then
			headers = false
			self.inputMode = InputMode(self.metadata.input)
			self.columns = self.inputMode:getColumns()
			self.inputMap = self.inputMode:getInputMap()
		elseif headers then
			local k, v = line:match("^(.-)=(.*)$")
			self.metadata[k] = v
		elseif line ~= "" then
			self:processLine(line)
		end
	end
	self:updateTime()
end

---@param s string
---@return ncdk.Fraction?
---@return number
---@return number
function SPH:parseNumber(s)
	local sign = 1
	local signLength = 0
	if s:sub(1, 1) == "-" then
		sign = -1
		signLength = 1
		s = s:sub(2)
	end

	local n, d = s:match("^(%d+)/(%d+)")
	if n and d then
		local length = 1 + #n + #d + signLength
		local _d = tonumber(d)
		if _d == 0 then
			return nil, math.huge, length
		end
		local f = Fraction(sign * tonumber(n), tonumber(d))
		return f, f:tonumber(), length
	end

	local i, d = s:match("^(%d+)%.(%d+)")
	if i and d then
		local length = 1 + #i + #d
		local _n = sign * tonumber(s:sub(1, length))
		return Fraction(_n, 1000, true), _n, length + signLength
	end

	local i = s:match("^(%d+)")
	if i then
		local _n = sign * tonumber(i)
		return Fraction(_n), _n, #i + signLength
	end

	return Fraction(0), 0, 0
end

---@param s string
function SPH:processLine(s)
	local expanded
	if s:sub(1, 1) == "." then
		expanded = true
		s = s:sub(2)
	elseif s == "-" then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
		return
	end

	if not expanded then
		self.expandOffset = 0
	end

	local columns = self.columns
	local notes = s:sub(1, columns)
	local info = s:sub(columns + 1, -1)

	local intervalOffset, fraction, velocity, expand, visual, measure

	local charOffset = 0
	while charOffset < #info do
		local k = info:sub(1, 1)
		local f, n, length = self:parseNumber(info:sub(2))

		if k == "=" then
			intervalOffset = n
		elseif k == "x" then
			velocity = n
		elseif k == "#" then
			measure = f
		end
		if not expanded then
			if k == "+" then
				fraction = f
				self.fraction = fraction
			elseif k == "e" then
				expand = n
			elseif k == "." then
				visual = true
			end
		else
			if k == "+" then
				expand = n - self.expandOffset
				self.expandOffset = n
			end
		end

		info = info:sub(length + 2)
	end

	if expanded and not expand then
		expand = math.floor(self.expandOffset) + 1 - self.expandOffset
		self.expandOffset = 0
	end

	if not fraction and not visual and not expanded then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
	end

	local intervals = self.intervals
	local interval
	if intervalOffset then
		interval = {
			offset = intervalOffset,
			beats = 1,
			beatOffset = self.beatOffset,
			start = self.fraction
		}
		local prev = intervals[#intervals]
		if prev then
			prev.beats = self.beatOffset - prev.beatOffset
		end
		table.insert(intervals, interval)
	end

	local _notes = {}
	for i = 1, #notes do
		local note = notes:sub(i, i)
		_notes[i] = note
	end

	local line = {
		intervalIndex = math.max(#intervals, 1),
		time = Fraction(self.beatOffset) + self.fraction,
		notes = _notes,
		velocity = velocity,
		expand = expand,
		measure = measure,
	}
	if interval then
		interval.line = line
	end
	table.insert(self.lines, line)
end

function SPH:updateTime()
	local lines = self.lines
	local intervals = self.intervals

	local time
	local intervalIndex
	local visualSide = 0
	for _, line in ipairs(lines) do
		local interval = intervals[line.intervalIndex]
		line.time = line.time - interval.beatOffset
		if time ~= line.time or intervalIndex ~= line.intervalIndex then
			time = line.time
			visualSide = 0
		else
			visualSide = visualSide + 1
		end
		line.visualSide = visualSide
	end
end

local defaultChart = [[title=title
artist=artist
name=name
creator=creator
source=
level=0
tags=
audio=audio.mp3
background=background.jpg
bpm=100
preview=0
input=4key

0000=0
0000=1
]]

---@param info table
---@return string
function SPH:getDefault(info)
	local chart = defaultChart
	for k, v in pairs(info) do
		chart = chart:gsub(k .. "=[^\n]*\n", k .. "=" .. v .. "\n")
	end
	return chart
end

return SPH
