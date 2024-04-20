local class = require("class")
local Fraction = require("ncdk.Fraction")

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

---@param lines table
function SphLines:decode(lines)
	for _, line in ipairs(lines) do
		self:decodeLine(line)
	end
	self:updateTime()
end

---@param tline table
function SphLines:decodeLine(tline)
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

	if not intervalOffset and not next(line) then
		return
	end

	line.intervalIndex = math.max(#self.intervals, 1)
	line.intervalSet = intervalOffset ~= nil
	line.globalTime = Fraction(self.beatOffset) + self.fraction
	line.visualSide = self.visualSide

	table.insert(self.protoLines, line)
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

---@return table
function SphLines:encode()
	local protoLines = self.protoLines
	local intervals = self.intervals
	local tlines = {}

	self:calcIntervals()
	self:calcGlobalTime()

	local lineIndex = 1
	local line = protoLines[1]

	local currentTime = line.globalTime
	local prevTime = nil
	while line do
		local targetTime = Fraction(currentTime:floor() + 1)
		if line.globalTime < targetTime then
			targetTime = line.globalTime
		end
		local isAtTimePoint = line.globalTime == targetTime

		if isAtTimePoint then
			local hasPayload =
				line.notes or
				line.expand or
				line.intervalSet or
				line.velocity or
				line.measure

			local isNextTime = line.globalTime ~= prevTime
			if isNextTime then
				prevTime = line.globalTime
			end

			local visual = not isNextTime
			-- local visual = not isNextTime and (line.visualSide or 0) > 0

			local fraction = line.globalTime % 1

			local tline = {}
			tline.notes = line.notes

			if (line.visualSide or 0) == 0 then
				if line.intervalSet then
					tline.offset = intervals[line.intervalIndex].offset
				end
				if fraction[1] ~= 0 then
					tline.fraction = line.globalTime % 1
				end
			else
				tline.visual = true
			end
			tline.expand = line.expand
			tline.velocity = line.velocity
			tline.measure = line.measure
			tline.comment = line.comment
			if line.sounds and next(line.sounds) then
				tline.sounds = line.sounds
			end
			if line.volume and next(line.volume) then
				tline.volume = line.volume
			end

			if hasPayload or fraction[1] == 0 and not visual then
				table.insert(tlines, tline)
			end

			lineIndex = lineIndex + 1
			line = protoLines[lineIndex]
		else
			table.insert(tlines, {})
		end
		currentTime = targetTime
	end

	return tlines
end

return SphLines
