local TimingDataImporter = {}

local TimingDataImporter_metatable = {}
TimingDataImporter_metatable.__index = TimingDataImporter

TimingDataImporter.new = function(self)
	local timingDataImporter = {}
	
	setmetatable(timingDataImporter, TimingDataImporter_metatable)
	
	return timingDataImporter
end

TimingDataImporter.init = function(self)
	self.startTime = self.timingPoint.StartTime
	self.offset = self.timingPoint.StartTime
	self.singature = self.timingPoint.Singature or 4
	self.bpm = self.timingPoint.Bpm
	self.multiplier = self.timingPoint.Multiplier
	
	self.timingChange = self.bpm ~= nil
	
	if self.bpm then
		self.beatLength = 60000 / self.bpm
		self.measureLength = math.abs(60000 / self.bpm * self.singature)
	else
		self.beatLength = -100 / self.multiplier
	end
end

return TimingDataImporter
