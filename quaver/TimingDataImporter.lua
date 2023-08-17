local class = require("class")

---@class quaver.TimingDataImporter
---@operator call: quaver.TimingDataImporter
local TimingDataImporter = class()

function TimingDataImporter:init()
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
