local class = require("class")
local Fraction = require("ncdk.Fraction")
local Line = require("sph.lines.Line")

---@class sph.SphLines
---@operator call: sph.SphLines
local SphLines = class()

function SphLines:new()
	self.protoLines = {}
	self.intervals = {}
	self.beatOffset = -1
	self.visualSide = 0
	self.fraction = {0, 1}
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

---@param lines sph.Line
function SphLines:decode(lines)
	for _, line in ipairs(lines) do
		self:decodeLine(line)
	end
	self:updateTime()
end

---@param line sph.Line
function SphLines:decodeLine(line)
	local pline = {}

	pline.comment = line.comment
	local intervalOffset = line.offset

	local fraction
	if line.fraction then
		fraction = line.fraction
		self.fraction = fraction
	end

	local visual = line.visual

	pline.measure = line.measure
	pline.sounds = line.sounds
	pline.volume = line.volume
	pline.velocity = line.velocity
	pline.expand = line.expand

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

	pline.notes = line.notes

	if not intervalOffset and not next(pline) then
		return
	end

	pline.intervalIndex = math.max(#self.intervals, 1)
	pline.intervalSet = intervalOffset ~= nil
	pline.globalTime = Fraction(self.beatOffset) + self.fraction
	pline.visualSide = self.visualSide

	table.insert(self.protoLines, pline)
end

function SphLines:updateTime()
	local protoLines = self.protoLines
	local intervals = self.intervals

	for _, line in ipairs(protoLines) do
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
	local protoLines = self.protoLines
	local intervals = self.intervals

	for _, line in ipairs(protoLines) do
		local interval = intervals[line.intervalIndex]
		line.globalTime = line.time + interval.beatOffset
	end
end

---@return sph.Line[]
function SphLines:encode()
	local protoLines = self.protoLines
	local intervals = self.intervals
	local lines = {}

	self:calcIntervals()
	self:calcGlobalTime()

	local plineIndex = 1
	local pline = protoLines[plineIndex]

	local currentTime = pline.globalTime
	local prevTime = nil
	while pline do
		local targetTime = Fraction(currentTime:floor() + 1)
		if pline.globalTime < targetTime then
			targetTime = pline.globalTime
		end
		local isAtTimePoint = pline.globalTime == targetTime

		if isAtTimePoint then
			local hasPayload =
				pline.notes or
				pline.expand or
				pline.intervalSet or
				pline.velocity or
				pline.measure

			local isNextTime = pline.globalTime ~= prevTime
			if isNextTime then
				prevTime = pline.globalTime
			end

			local visual = not isNextTime

			local fraction = pline.globalTime % 1

			local line = Line()
			line.notes = pline.notes

			if (pline.visualSide or 0) == 0 then
				if pline.intervalSet then
					line.offset = intervals[pline.intervalIndex].offset
				end
				if fraction[1] ~= 0 then
					line.fraction = pline.globalTime % 1
				end
			else
				line.visual = true
			end
			line.expand = pline.expand
			line.velocity = pline.velocity
			line.measure = pline.measure
			line.comment = pline.comment
			if pline.sounds and next(pline.sounds) then
				line.sounds = pline.sounds
			end
			if pline.volume and next(pline.volume) then
				line.volume = pline.volume
			end

			if hasPayload or fraction[1] == 0 and not visual then
				table.insert(lines, line)
			end

			plineIndex = plineIndex + 1
			pline = protoLines[plineIndex]
		else
			table.insert(lines, {})
		end
		currentTime = targetTime
	end

	return lines
end

return SphLines
