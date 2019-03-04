local TimingDataImporter = {}

local TimingDataImporter_metatable = {}
TimingDataImporter_metatable.__index = TimingDataImporter

TimingDataImporter.new = function(self)
	local timingDataImporter = {}
	
	setmetatable(timingDataImporter, TimingDataImporter_metatable)
	
	return timingDataImporter
end

TimingDataImporter.init = function(self)
	self.lineTable = self.line:split(",")
	
	self.offset = tonumber(self.lineTable[1])
	self.beatLength = tonumber(self.lineTable[2])
	self.timingSignature = tonumber(self.lineTable[3])
	self.sampleSetId = tonumber(self.lineTable[4])
	self.customSampleIndex = tonumber(self.lineTable[5])
	self.sampleVolume = tonumber(self.lineTable[6])
	self.timingChange = tonumber(self.lineTable[7]) == 1
	self.kiaiTimeActive = tonumber(self.lineTable[8])
	
	self.startTime = self.offset
	self.measureLength = math.abs(self.beatLength * self.timingSignature)
	
	if self.timingChange then
		self.beatLength = math.abs(self.beatLength)
	else
		self.velocity = math.min(math.max(0.1, math.abs(-100 / self.beatLength)), 10)
	end
end

return TimingDataImporter
