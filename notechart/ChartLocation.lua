local class = require("class")
local table_util = require("table_util")
local path_util = require("path_util")

---@class notechart.ChartLocation
---@operator call: notechart.ChartLocation
local ChartLocation = class()

local Unrelated = table_util.invert({
	"ojn",
	"mid",
	"midi",
})

---@param filename string
---@return boolean
function ChartLocation:isUnrelated(filename)
	return Unrelated[path_util.ext(filename, true)] ~= nil
end

---@param filename string
---@return boolean
function ChartLocation:isRelated(filename)
	return not self:isUnrelated(filename)
end

return ChartLocation
