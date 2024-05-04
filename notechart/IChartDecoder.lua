local class = require("class")

---@class chartbase.IChartDecoder
---@operator call: chartbase.IChartDecoder
local IChartDecoder = class()

---@param s string
---@return ncdk2.Chart[]
function IChartDecoder:decode(s)
	return {}
end

return IChartDecoder
