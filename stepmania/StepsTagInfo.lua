local class = require("class")

---@class stepmania.StepsTagInfo
---@operator call: stepmania.StepsTagInfo
---@field loader stepmania.SSCLoader
---@field song stepmania.Song
---@field steps stepmania.Steps
---@field timing stepmania.TimingData
---@field params string[]
---@field path string
---@field has_own_timing boolean
---@field ssc_format boolean
---@field from_cache boolean
---@field for_load_edit boolean
local StepsTagInfo = class()

StepsTagInfo.has_own_timing = false
StepsTagInfo.ssc_format = false
StepsTagInfo.ssc_format = false
StepsTagInfo.for_load_edit = false

---@param l stepmania.SSCLoader
---@param s stepmania.Song
---@param p string
---@param fc boolean
function StepsTagInfo:new(l, s, p, fc)
	self.loader = l
	self.song = s
	self.path = p
	self.from_cache = fc
end

return StepsTagInfo
