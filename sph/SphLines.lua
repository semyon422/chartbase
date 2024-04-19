local class = require("class")
local Fraction = require("ncdk.Fraction")
local TextSphLines = require("sph.TextSphLines")
local SphLinesCleaner = require("sph.SphLinesCleaner")

---@class sph.SphLines
---@operator call: sph.SphLines
local SphLines = class()

function SphLines:new()
	self.lines = {}
	self.intervals = {}
	self.beatOffset = -1
	self.visualSide = 0
	self.fraction = {0, 1}
	self.columns = 1
	self.textSphLines = TextSphLines()
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
function SphLines:decodeLine(s)
	local tline = self.textSphLines:decodeLine(s)
	self.columns = self.textSphLines.columns

	local line = {}

	line.comment = tline.comment
	local intervalOffset = tline.offset

	local fraction
	if tline.fraction then
		fraction = tline.fraction
		self.fraction = fraction
	end

	local visual = tline.visual

	line.measure = tline.measure
	line.sounds = tline.sounds
	line.volume = tline.volume
	line.velocity = tline.velocity
	line.expand = tline.expand

	if visual then
		self.visualSide = self.visualSide + 1
	else
		self.visualSide = 0
	end

	if not fraction and not visual then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
	end

	if intervalOffset then
		self:addInterval(intervalOffset)
	end

	line.notes = tline.notes
	line.intervalIndex = math.max(#self.intervals, 1)
	line.intervalSet = intervalOffset ~= nil
	line.globalTime = Fraction(self.beatOffset) + self.fraction
	line.visualSide = self.visualSide

	table.insert(self.lines, line)
end

function SphLines:updateTime()
	local lines = self.lines
	local intervals = self.intervals

	for _, line in ipairs(lines) do
		local interval = intervals[line.intervalIndex]
		line.time = line.globalTime - interval.beatOffset
	end
end

function SphLines:calcIntervals()
	local intervals = self.intervals
	local beatOffset = 0
	for i = 1, #intervals do
		local int = intervals[i]
		int.beatOffset = beatOffset
		beatOffset = beatOffset + int.beats
	end
end

function SphLines:calcGlobalTime()
	local lines = self.lines
	local intervals = self.intervals

	for _, line in ipairs(lines) do
		local interval = intervals[line.intervalIndex]
		line.globalTime = line.time + interval.beatOffset
	end
end

---@return string
function SphLines:encode()
	local lines = self.lines
	local intervals = self.intervals
	local tlines = {}

	self:calcIntervals()
	self:calcGlobalTime()

	for i, line in ipairs(lines) do
		local tline = {}
		tline.notes = line.notes

		if (line.visualSide or 0) == 0 then
			if line.intervalSet then
				tline.offset = intervals[line.intervalIndex].offset
			end
			local fraction = line.globalTime % 1
			if fraction[1] ~= 0 then
				tline.fraction = line.globalTime % 1
			end
		else
			tline.visual = true
		end
		tline.expand = line.expand
		tline.velocity = line.velocity
		tline.measure = line.measure
		tline.sounds = line.sounds
		tline.volume = line.volume
		tline.comment = line.comment
		table.insert(tlines, tline)
	end

	local textSphLines = TextSphLines()
	textSphLines.columns = self.columns
	textSphLines.lines = SphLinesCleaner:clean(tlines)
	return textSphLines:encode()
end

return SphLines
