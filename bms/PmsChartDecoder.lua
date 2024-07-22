local ChartDecoder = require("bms.ChartDecoder")
local Bms = require("bms.BMS")

---@class bms.PmsChartDecoder: bms.ChartDecoder
---@operator call: bms.PmsChartDecoder
local PmsChartDecoder = ChartDecoder + {}

---@param s string
---@return ncdk2.Chart[]
function PmsChartDecoder:decode(s)
	local bms = Bms()
	bms.pms = true
	local content = s:gsub("\r[\r\n]?", "\n")
	content = self.conv:convert(content)
	bms:import(content)
	local chart = self:decodeBms(bms)
	return {chart}
end

return PmsChartDecoder
