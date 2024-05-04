local class = require("class")

---@class chartbase.IChartEncoder
---@operator call: chartbase.IChartEncoder
local IChartEncoder = class()

---@param charts ncdk2.Chart[]
---@return string
function IChartEncoder:encode(charts)
	return ""
end

return IChartEncoder
