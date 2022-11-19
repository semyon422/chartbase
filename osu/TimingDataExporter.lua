local TimingDataExporter = {}

local TimingDataExporter_metatable = {}
TimingDataExporter_metatable.__index = TimingDataExporter

TimingDataExporter.new = function(self)
	local timingDataExporter = {}

	setmetatable(timingDataExporter, TimingDataExporter_metatable)

	return timingDataExporter
end

local timingPointString = "%s,%s,4,2,0,100,%s,0"
TimingDataExporter.getTempo = function(self)
	return timingPointString:format(
		self.tempoData.timePoint.absoluteTime * 1000,
		self.tempoData:getBeatDuration() * 1000,
		1
	)
end

TimingDataExporter.getStop = function(self)
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

TimingDataExporter.getVelocity = function(self)
	return timingPointString:format(
		self.velocityData.timePoint.absoluteTime * 1000,
		-100 / (self.velocityData.clearCurrentSpeed or self.velocityData.currentSpeed),
		0
	)
end

return TimingDataExporter
