local Fraction = require("ncdk.Fraction")

local SPH = {}

local mt = {__index = SPH}

function SPH:new()
	local sph = {}

	sph.metadata = {}
	sph.lines = {}
	sph.intervals = {}
	sph.beatOffset = 0

	return setmetatable(sph, mt)
end

function SPH:import(s)
	local headers = true
	for _, line in ipairs(s:split("\n")) do
		if line == "" then
			headers = false
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
	local notes, info = s:match("^([^:]+)(.*)$")

	local intervalOffset
	for _, pair in ipairs(info:gsub("^:", ""):split(",")) do
		local k, v = pair:match("^(.-)=(.+)$")
		if k == "t" then
			intervalOffset = tonumber(v)
		end
	end

	local fraction
	local _notes, n, d = notes:match("^(.+)%+(.+)/(.+)$")
	if _notes then
		notes = _notes
		fraction = {tonumber(n), tonumber(d)}
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

	_notes = {}
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
	})

	if not fraction then
		self.beatOffset = self.beatOffset + 1
	end
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
