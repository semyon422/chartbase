local class = require("class")

---@class osu.RawOsu
---@operator call: osu.RawOsu
local RawOsu = class()

RawOsu.version = 14

local sections_order = {
	"General",
	"Editor",
	"Metadata",
	"Difficulty",
	"Events",
	"TimingPoints",
	"HitObjects",
}

function RawOsu:new()

end

return RawOsu
