local class = require("class")

---@class osu.TimingDataExporter
---@operator call: osu.TimingDataExporter
local TimingDataExporter = class()

local timingPointString = "%s,%s,4,2,0,100,%s,0"

---@return string
function TimingDataExporter:getTempo()
	return timingPointString:format(
		self.tempoData.timePoint.absoluteTime * 1000,
		self.tempoData:getBeatDuration() * 1000,
		1
	)
end

---@return string
function TimingDataExporter:getStop()
	return
	timingPointString:format(
		self.stopData.leftTimePoint.absoluteTime * 1000,
		60000000,
		1
	) .. "\n" ..
	timingPointString:format(
		self.stopData.timePoint.absoluteTime * 1000,
		self.stopData.tempoData:getBeatDuration() * 1000,
		1
	)
end

---@return string
function TimingDataExporter:getVelocity()
	return timingPointString:format(
		self.velocityData.timePoint.absoluteTime * 1000,
		-100 / self.velocityData.currentSpeed,
		0
	)
end

---@return string
function TimingDataExporter:getInterval()
	return timingPointString:format(
		self.intervalData.timePoint.absoluteTime * 1000,
		self.intervalData:getBeatDuration() * 1000,
		1
	)
end

return TimingDataExporter
