local class = require("class")

---@class osu.TimingDataImporter
---@operator call: osu.TimingDataImporter
local TimingDataImporter = class()

function TimingDataImporter:init()
	self.startTime = self.offset
end

return TimingDataImporter
