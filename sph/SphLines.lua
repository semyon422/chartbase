local class = require("class")
local Fraction = require("ncdk.Fraction")
local SphNumber = require("sph.SphNumber")
local template_key = require("sph.template_key")

---@class sph.SphLines
---@operator call: sph.SphLines
local SphLines = class()

function SphLines:new()
	self.lines = {}
	self.intervals = {}
	self.beatOffset = -1
	self.visualSide = 0
	self.fraction = {0, 1}
	self.sphNumber = SphNumber()
	self.columns = 1
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
---@return table
local function parse_notes(notes)
	local out = {}
	for i, note in ipairs(notes) do
		if note ~= "0" then
			table.insert(out, {
				column = i,
				type = note,
			})
		end
	end
	return out
end

---@param sounds table
---@return table
local function parse_sounds(sounds)
	local out = {}
	for i, sound in ipairs(sounds) do
		out[i] = template_key.decode(sound)
	end
	return out
end

---@param s string
function SphLines:decodeLine(s)
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
			line.sounds = parse_sounds(split_chars(v, 2))
		elseif k == "x" then
			line.velocity = tonumber(v)
		elseif k == "e" then
			line.expand = tonumber(v)
		end
	end

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

	if args[1] ~= "-" then
		self.columns = math.max(self.columns, #args[1])
		local notes = split_chars(args[1], 1)
		line.notes = parse_notes(notes)
	end

	if not intervalOffset and not next(line) then
		return
	end

	line.notes = line.notes or {}
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

---@param f ncdk.Fraction
---@return string
local function formatFraction(f)
	return f[1] .. "/" .. f[2]
end

---@param _notes table
---@return string?
function SphLines:getLine(_notes)
	if not _notes or #_notes == 0 then
		return
	end
	local notes = {}
	for i = 1, self.columns do
		notes[i] = "0"
	end
	for _, note in ipairs(_notes) do
		if note.column then
			notes[note.column] = note.type
		end
	end
	return table.concat(notes)
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

	for _, line in ipairs(lines) do
		if line.notes then
			for _, note in ipairs(line.notes) do
				if note.column then
					self.columns = math.max(self.columns, note.column)
				end
			end
		end
	end

	local lineIndex = 1
	local line = lines[1]

	local slines = {}

	self:calcIntervals()
	self:calcGlobalTime()

	local currentTime = line.globalTime
	local prevTime = nil
	while line do
		local targetTime = Fraction(currentTime:floor() + 1)
		if line.globalTime < targetTime then
			targetTime = line.globalTime
		end
		local isAtTimePoint = line.globalTime == targetTime

		if isAtTimePoint then
			local str = self:getLine(line.notes)

			local hasPayload =
				str or
				line.expand or
				line.intervalSet or
				line.velocity or
				line.measure

			if line.globalTime ~= prevTime then
				prevTime = line.globalTime
			end

			local visual = (line.visualSide or 0) > 0

			str = str or "-"
			local dt = line.globalTime % 1
			if not visual then
				if line.intervalSet then
					str = str .. " =" .. intervals[line.intervalIndex].offset
				end
				if dt[1] ~= 0 then
					str = str .. " +" .. formatFraction(dt)
				end
			else
				str = str .. " v"
			end
			if line.expand then
				str = str .. " e" .. tostring(line.expand)
			end
			if line.velocity then
				str = str .. " x" .. tostring(line.velocity)
			end
			if line.measure then
				local n = line.measure
				str = str .. " #" .. (n[1] ~= 0 and formatFraction(n) or "")
			end
			if line.sounds and #line.sounds > 0 then
				local out = {}
				for i, sound in ipairs(line.sounds) do
					out[i] = template_key.encode(sound)
				end
				str = str .. " :" .. table.concat(out)
			end

			if hasPayload or dt[1] == 0 and not visual then
				table.insert(slines, str)
			end

			lineIndex = lineIndex + 1
			line = lines[lineIndex]
		else
			table.insert(slines, "-")
		end
		currentTime = targetTime
	end

	local first, last
	for i = 1, #slines do
		if slines[i] ~= "-" then
			first = i
			break
		end
	end
	for i = #slines, 1, -1 do
		if slines[i] ~= "-" then
			last = i
			break
		end
	end

	local trimmed_lines = {}
	for i = first, last do
		table.insert(trimmed_lines, slines[i])
	end

	return table.concat(trimmed_lines, "\n")
end

return SphLines
