local TimingDataImporter = {}

local TimingDataImporter_metatable = {}
TimingDataImporter_metatable.__index = TimingDataImporter

TimingDataImporter.new = function(self, tp)
	local timingDataImporter = tp or {}
	
	setmetatable(timingDataImporter, TimingDataImporter_metatable)
	
	return timingDataImporter
end

TimingDataImporter.init = function(self)
	self.startTime = self.offset
end

return TimingDataImporter
