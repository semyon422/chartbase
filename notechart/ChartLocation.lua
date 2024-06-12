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

local Related = table_util.invert({
	"osu",
	"bms",
	"bme",
	"bml",
	"pms",
	"qua",
	"ksh",
	"sph",
	"sm",
})

---@param filename string
---@return boolean
function ChartLocation:isUnrelated(filename)
	return Unrelated[path_util.ext(filename, true)] ~= nil
end

---@param filename string
---@return boolean
function ChartLocation:isRelated(filename)
	return Related[path_util.ext(filename, true)] ~= nil
end

return ChartLocation
