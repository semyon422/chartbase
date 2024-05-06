local Section = require("osu.sections.Section")

---@class osu.ControlPoint
---@field offset number
---@field beatLength number
---@field timeSignature number
---@field sampleSet number
---@field customSamples number
---@field volume number
---@field timingChange boolean
---@field effectFlags number

---@class osu.TimingPoints: osu.Section
---@operator call: osu.TimingPoints
---@field points osu.ControlPoint[]
local TimingPoints = Section + {}

TimingPoints.sampleVolume = 100
TimingPoints.defaultSampleSet = 0

---@param sampleVolume number
---@param defaultSampleSet number
function TimingPoints:new(sampleVolume, defaultSampleSet)
	self.sampleVolume = sampleVolume
	self.defaultSampleSet = defaultSampleSet
	self.points = {}
end

---@param line string
function TimingPoints:decodeLine(line)
	---@type string[]
	local split = line:split(",")
	local size = #split

	if size < 2 then
		return
	end

	---@type number[]
	local splitn = {}
	for i, v in ipairs(split) do
		splitn[i] = assert(tonumber(v))
	end

	local point = {}
	---@cast point osu.ControlPoint

	point.offset = splitn[1]
	point.beatLength = splitn[2]

	if size == 2 then
		point.timeSignature = 4
		point.sampleSet = self.defaultSampleSet
		point.customSamples = 0
		point.volume = 100
		point.timingChange = true
		point.effectFlags = 0
		table.insert(self.points, point)
		return
	end

	point.timeSignature = splitn[3] == 0 and 4 or splitn[3] or 4
	point.sampleSet = splitn[4] or 0
	point.customSamples = splitn[5] or 0
	point.volume = splitn[6] or self.sampleVolume
	point.timingChange = splitn[7] == 1
	if not splitn[7] then
		point.timingChange = true  -- can't use `or` here
	end
	point.effectFlags = splitn[8] or 0

	table.insert(self.points, point)
end

---@return string[]
function TimingPoints:encode()
	local out = {}

	for _, p in ipairs(self.points) do
		table.insert(out, ("%.16g,%.16g,%s,%s,%s,%s,%s,%s"):format(
			p.offset,
			p.beatLength,
			p.timeSignature,
			p.sampleSet,
			p.customSamples,
			p.volume,
			p.timingChange and 1 or 0,
			p.effectFlags
		))
	end

	-- osu adds \r\n at the end of each timing point
	-- and one new line before each section
	-- that is why there is additional empty line
	table.insert(out, "")

	return out
end

return TimingPoints
