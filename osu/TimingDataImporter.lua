local class = require("class")

local TimingDataImporter = class()

function TimingDataImporter:init()
	self.startTime = self.offset
end

return TimingDataImporter
