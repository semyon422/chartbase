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

	return setmetatable(sph, mt)
end

function SPH:import(s)
	local headers = true
	for _, line in ipairs(s:split("\n")) do
		if line == "" then
			headers = false
			self.inputMode = InputMode:new(self.metadata.input)
			self.columns = self.inputMode:getColumns()
			self.inputMap = self.inputMode:getInputMap()
		elseif headers then
			local k, v = line:match("^(.-)=(.*)$")
			self.metadata[k] = v
		else
			self:processLine(line)
		end
	end
	self:updateTime()
end

function SPH:processLine(s)
	local columns = self.columns
	local notes = s:sub(1, columns)
	local info = s:sub(columns + 1, -1)

	local intervalOffset, fraction, velocity, expand

	local charOffset = 0
	while charOffset < #info do
		local k, n, d = info:match("^(.)(%d+)/(%d+)")
		local length
		if not k then
			k, n = info:match("^(.)(%d+)")
			d = 1
			length = #n + 1
		else
			length = #n + #d + 2
		end
		n, d = tonumber(n), tonumber(d)

		if k == "=" then
			intervalOffset = n
		elseif k == "+" then
			fraction = {n, d}
		elseif k == "x" then
			velocity = n / d
		elseif k == "e" then
			expand = n / d
		end

		info = info:sub(length + 1)
	end

	if not fraction then
		self.beatOffset = self.beatOffset + 1
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
	if velocity then
		interval = {
			offset = intervalOffset,
			intervals = 1,
			beatOffset = self.beatOffset,
		}
	end

	local _notes = {}
	for i = 1, #notes do
		local note = notes:sub(i, i)
		_notes[i] = note
	end

	table.insert(self.lines, {
		interval = interval,
		intervalIndex = math.max(#self.intervals, 1),
		beatOffset = self.beatOffset,
		fraction = fraction,
		notes = _notes,
		velocity = velocity,
		expand = expand,
	})
end

function SPH:updateTime()
	local lines = self.lines
	local intervals = self.intervals

	local prevInterval
	for _, line in ipairs(lines) do
		local interval = intervals[line.intervalIndex]
		local beatOffset = line.beatOffset - interval.beatOffset
		line.time = Fraction(beatOffset) + line.fraction

		prevInterval = prevInterval or interval
		if prevInterval ~= interval then
			prevInterval.intervals = interval.beatOffset - prevInterval.beatOffset
			prevInterval = interval
		end
	end
end

return SPH
