local class = require("class")
local Fraction = require("ncdk.Fraction")
local SphNumber = require("sph.SphNumber")

---@class sph.SphLines
---@operator call: sph.SphLines
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
---@param n number
---@return table
local function split_chars(s, n)
	local chars = {}
	for i = 1, #s, n do
		table.insert(chars, s:sub(i, i + n - 1))
	end
	return chars
end

---@param notes table
---@param templates table
---@return table
local function parse_notes(notes, templates)
	local out = {}

	for i, note in ipairs(notes) do
		if note ~= "0" then
			table.insert(out, {
				column = i,
				type = note,
			})
		end
	end

	if templates then
		for i, template in ipairs(templates) do
			if out[i] then
				out[i].template = template
			else
				table.insert(out, {template = template})
			end
		end
	end

	return out
end

---@param s string
function SphLines:processLine(s)
	if s == "-" then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
		return
	end

	local intervalOffset, fraction, visual
	local line = {}

	local args = s:split(" ")
	for i = 2, #args do
		local k, v = args[i]:match("^(.)(.*)$")

		if k == "=" then
			intervalOffset = tonumber(v)
		elseif k == "+" then
			fraction = self.sphNumber:decode(v)
			self.fraction = fraction
		elseif k == "v" then
			visual = true
		elseif k == "#" then
			line.measure = self.sphNumber:decode(v)
		elseif k == ":" then
			line.templates = split_chars(v, 2)
		elseif k == "x" then
			line.velocity = tonumber(v)
		elseif k == "e" then
			line.expand = tonumber(v)
		end
	end

	if not fraction and not visual then
		self.beatOffset = self.beatOffset + 1
		self.fraction = nil
	end

	if intervalOffset then
		self:addInterval(intervalOffset)
	end

	local notes = split_chars(args[1], 1)
	line.notes = parse_notes(notes, line.templates)

	line.intervalIndex = math.max(#self.intervals, 1)
	line.time = Fraction(self.beatOffset) + self.fraction

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
