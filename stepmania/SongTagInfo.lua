local class = require("class")

---@class stepmania.SongTagInfo
---@operator call: stepmania.SongTagInfo
---@field loader stepmania.SSCLoader
---@field song stepmania.Song
---@field params string[]
---@field path string
---@field from_cache boolean
local SongTagInfo = class()

---@param l stepmania.SSCLoader
---@param s stepmania.Song
---@param p string
---@param fc boolean
function SongTagInfo:new(l, s, p, fc)
	self.loader = l
	self.song = s
	self.path = p
	self.from_cache = fc
end

return SongTagInfo
