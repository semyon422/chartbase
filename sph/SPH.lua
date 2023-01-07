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
	sph.beatOffset = -1
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

function SPH:processLine(s)
	local expanded, empty
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
		local k, n, d = info:match("^(.)(%d+)/(%d+)")
		local length
		if not k then
			k, n = info:match("^(.)(%d+)")
			if k then
				d = 1
				length = #n + 1
			else
				k = info:match("^(.)")
				length = 1
			end
		else
			length = #n + #d + 2
		end
		n, d = tonumber(n), tonumber(d)

		if not expanded then
			if k == "=" then
				intervalOffset = n
			elseif k == "+" then
				fraction = {n, d}
				self.fraction = fraction
			elseif k == "x" then
				velocity = n / d
			elseif k == "e" then
				expand = n / d
			elseif k == "." then
				visual = true
			end
		else
			if k == "+" then
				expand = n / d - self.expandOffset
				self.expandOffset = n / d
			elseif k == "x" then
				velocity = n / d
			end
		end

		info = info:sub(length + 1)
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
			intervals = 1,
			beatOffset = self.beatOffset,
		}
		table.insert(self.intervals, interval)
	end

	local _notes = {}
	for i = 1, #notes do
		local note = notes:sub(i, i)
		_notes[i] = note
	end

	table.insert(self.lines, {
		intervalIndex = math.max(#self.intervals, 1),
		beatOffset = self.beatOffset,
		fraction = self.fraction,
		notes = _notes,
		velocity = velocity,
		expand = expand,
	})
end

function SPH:updateTime()
	local lines = self.lines
	local intervals = self.intervals

	local time
	local visualSide = 0
	local prevInterval
	for _, line in ipairs(lines) do
		local interval = intervals[line.intervalIndex]
		local beatOffset = line.beatOffset - interval.beatOffset
		line.time = Fraction(beatOffset) + line.fraction
		if time ~= line.time then
			time = line.time
			visualSide = 0
		else
			visualSide = visualSide + 1
		end
		line.visualSide = visualSide

		prevInterval = prevInterval or interval
		if prevInterval ~= interval then
			prevInterval.intervals = interval.beatOffset - prevInterval.beatOffset
			prevInterval = interval
		end
	end
end

return SPH
