local class = require("class")
local Fraction = require("ncdk.Fraction")
local SphNumber = require("sph.SphNumber")

local SphLines = class()

function SphLines:new()
	self.lines = {}
	self.intervals = {}
	self.beatOffset = -1
	self.fraction = {0, 1}
	self.sphNumber = SphNumber()
end

---@param intervalOffset number
function SphLines:addInterval(intervalOffset)
	local intervals = self.intervals
	local interval = {
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

---@param s string
function SphLines:processLine(s)
	if s == "-" then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
		return
	end

	local columns = self.columns

	local intervalOffset, fraction, visual
	local line = {}

	local info = s:sub(columns + 1, -1)
	local charOffset = 0
	while charOffset < #info do
		local k = info:sub(1, 1)
		local f, n, length = self.sphNumber:decode(info:sub(2))

		if k == "=" then
			intervalOffset = n
		elseif k == "+" then
			fraction = f
			self.fraction = fraction
		elseif k == "." then
			visual = true
		elseif k == "x" then
			line.velocity = n
		elseif k == "#" then
			line.measure = f
		elseif k == "e" then
			line.expand = n
		end

		info = info:sub(length + 2)
	end

	if not fraction and not visual then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
	end

	if intervalOffset then
		self:addInterval(intervalOffset)
	end

	local _notes = {}
	local notes = s:sub(1, columns)
	for i = 1, #notes do
		local note = notes:sub(i, i)
		_notes[i] = note
	end

	line.intervalIndex = math.max(#self.intervals, 1)
	line.time = Fraction(self.beatOffset) + self.fraction
	line.notes = _notes

	table.insert(self.lines, line)
end

function SphLines:updateTime()
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
			intervalIndex = line.intervalIndex
			visualSide = 0
		else
			visualSide = visualSide + 1
		end
		line.visualSide = visualSide
	end
end

return SphLines
