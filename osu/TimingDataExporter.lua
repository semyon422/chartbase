local TimingDataExporter = {}

local TimingDataExporter_metatable = {}
TimingDataExporter_metatable.__index = TimingDataExporter

TimingDataExporter.new = function(self)
	local timingDataExporter = {}
	
	setmetatable(timingDataExporter, TimingDataExporter_metatable)
	
	return timingDataExporter
end

local timingPointString = "%s,%s,4,2,0,100,1,0"
TimingDataExporter.getTempo = function(self)
	return timingPointString:format(
		self.tempoData.rightTimePoint:getAbsoluteTime() * 1000,
		self.tempoData:getBeatDuration() * 1000
	)
end

TimingDataExporter.getStop = function(self)
	return
	timingPointString:format(
		self.stopData.leftTimePoint:getAbsoluteTime() * 1000,
		60000000
	) .. "\n" ..
	timingPointString:format(
		self.stopData.tempoData.rightTimePoint:getAbsoluteTime() * 1000,
		self.stopData.tempoData:getBeatDuration() * 1000
	)
end

return TimingDataExporter
