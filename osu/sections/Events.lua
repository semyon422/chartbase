local Section = require("osu.sections.Section")
local table_util = require("table_util")

---@class osu.EventSample
---@field time number
---@field name string
---@field volume number

---@class osu.Events: osu.Section
---@operator call: osu.Events
---@field samples osu.EventSample[]
local Events = Section + {}

local EventTypes = {
	Background = 0,
	Video = 1,
	Break = 2,
	Colour = 3,
	Sprite = 4,
	Sample = 5,
	Animation = 6,
}

function Events:new()
	self.samples = {}
end

---@param lines string[]
function Events:decode(lines)
	for _, line in ipairs(lines) do
		self:decodeLine(line)
	end
end

local quoted_pattern = '^"?(.-)"?$'

---@param line string
function Events:decodeLine(line)
	if #line == 0 or line:find("^ ") or line:find("^_") or line:find("^//") then
		return
	end

	---@type string[]
	local split = line:split(",")

	-- comma is not allowed in file names
	-- osu uses split(",") and we will use

	local event_type = table_util.keyofenum(EventTypes, split[1])
	if event_type == "Background" then
		self.background = split[3]:match(quoted_pattern)
	elseif event_type == "Video" then
		self.video = {
			time = tonumber(split[2]) or 0,
			name = split[3]:match(quoted_pattern),
		}
	elseif event_type == "Sample" then  -- split[3] is layer, unused
		table.insert(self.samples, {
			time = tonumber(split[2]) or 0,
			name = split[4]:match(quoted_pattern),
			volume = tonumber(split[5]) or 100,
		})
	end
end

---@return string[]
function Events:encode()
	local out = {}

	if self.background then
		table.insert(out, ('%s,0,"%s",0,0'):format(EventTypes.Background, self.background))
	end
	if self.video then
		table.insert(out, ('%s,%s,"%s"'):format(EventTypes.Video, self.video.time, self.video.name))
	end
	for _, s in ipairs(self.samples) do
		table.insert(out, ('%s,%s,%s,"%s",%s'):format(EventTypes.Sample, s.time, 0, s.name, s.volume))
	end

	return out
end

return Events
