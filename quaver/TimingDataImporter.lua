local TimingDataImporter = {}

local TimingDataImporter_metatable = {}
TimingDataImporter_metatable.__index = TimingDataImporter

TimingDataImporter.new = function(self)
	local timingDataImporter = {}
	
	setmetatable(timingDataImporter, TimingDataImporter_metatable)
	
	return timingDataImporter
end

TimingDataImporter.init = function(self)
	self.startTime = self.timingPoint.StartTime or 0
	self.singature = self.timingPoint.Singature or 4
	self.bpm = self.timingPoint.Bpm
	self.multiplier = self.timingPoint.Multiplier or 0
	
	
	if self.bpm then
		self.timingChange = true
		self.beatLength = 60000 / self.bpm
		self.measureLength = math.abs(self.beatLength * self.singature)
	else
		self.timingChange = false
		self.velocity = self.multiplier
	end
end

return TimingDataImporter
