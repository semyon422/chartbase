local Fraction = require("ncdk.Fraction")
local InputMode = require("ncdk.InputMode")

local SPH = {}

local mt = {__index = SPH}

function SPH:new()
	local sph = {}

	sph.metadata = {}
	sph.lines = {}
	sph.intervals = {}
	sph.velocities = {}
	sph.expands = {}
	sph.beatOffset = Fraction(-1)
	sph.expandOffset = 0
	sph.fraction = {0, 1}

	return setmetatable(sph, mt)
end

function SPH:import(s)
	local headers = true
	for _, line in ipairs(s:split("\n")) do
		if line == "" and headers then
			headers = false
			self.inputMode = InputMode:new(self.metadata.input)
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

	local intervalOffset, fraction, velocity, expand, visual

	local charOffset = 0
	while charOffset < #info do
		local k = info:sub(1, 1)
		local f, n, length = self:parseNumber(info:sub(2))

		if not expanded then
			if k == "=" then
				intervalOffset = n
			elseif k == "+" then
				fraction = f
				self.fraction = fraction
			elseif k == "x" then
				velocity = n
			elseif k == "e" then
				expand = n
			elseif k == "." then
				visual = true
			end
		else
			if k == "+" then
				expand = n - self.expandOffset
				self.expandOffset = n
			elseif k == "x" then
				velocity = n
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

	local interval
	if intervalOffset then
		interval = {
			offset = intervalOffset,
			beats = Fraction(1),
			time = Fraction(self.beatOffset) + self.fraction
		}
		interval.start = interval.time % 1
		table.insert(self.intervals, interval)
	end

	local _notes = {}
	for i = 1, #notes do
		local note = notes:sub(i, i)
		_notes[i] = note
	end

	local line = {
		intervalIndex = math.max(#self.intervals, 1),
		time = Fraction(self.beatOffset) + self.fraction,
		notes = _notes,
		velocity = velocity,
		expand = expand,
	}
	if interval then
		interval.line = line
	end
	table.insert(self.lines, line)
end

function SPH:updateTime()
	local lines = self.lines
	local intervals = self.intervals

	for i = 1, #intervals - 1 do
		local interval, nextInterval = intervals[i], intervals[i + 1]
		interval.beats = nextInterval.time - interval.time
	end

	local time
	local visualSide = 0
	for _, line in ipairs(lines) do
		local interval = intervals[line.intervalIndex]
		line.time = line.time - interval.time + interval.start
		if time ~= line.time then
			time = line.time
			visualSide = 0
		else
			visualSide = visualSide + 1
		end
		line.visualSide = visualSide
	end
end

return SPH
