local class = require("class")
local SphLines = require("sph.SphLines")
local template_key = require("sph.lines.template_key")

---@class sph.Sph
---@operator call: sph.Sph
local Sph = class()

function Sph:new()
	self.metadata = {}
	self.sounds = {}
	self.sphLines = SphLines()
	self.section = ""
end

---@param line string
function Sph:decodeLine(line)
	if line == "" then
		return
	end

	local section = line:match("^# (.+)$")
	if section then
		self.section = section
	elseif self.section == "metadata" then
		local k, v = line:match("^(%w+) (.+)$")
		if k then
			self.metadata[k] = v
		end
	elseif self.section == "sounds" then
		local t, v = line:match("^(..) (.+)$")
		if t then
			self.sounds[template_key.decode(t)] = v
		end
	elseif self.section == "notes" then
		self.sphLines:decodeLine(line)
	end
end

---@param s string
function Sph:decode(s)
	for _, line in ipairs(s:split("\n")) do
		self:decodeLine(line)
	end
	self.sphLines:updateTime()
end

local headerLines = {
	"title",
	"artist",
	"name",
	"creator",
	"source",
	"level",
	"tags",
	"audio",
	"background",
	"preview",
	"input",
}

---@return string
function Sph:encode()
	local lines = {}

	table.insert(lines, "# metadata")
	local metadata = self.metadata
	for _, k in ipairs(headerLines) do
		local v = metadata[k]
		if v then
			table.insert(lines, ("%s %s"):format(k, v))
		end
	end
	table.insert(lines, "")

	local sounds = self.sounds
	if next(sounds) then
		table.insert(lines, "# sounds")
		local sorted_sounds = {}
		for t, v in pairs(sounds) do
			table.insert(sorted_sounds, {t, v})
		end
		table.sort(sorted_sounds, function(a, b)
			return a[1] < b[1]
		end)
		for _, s in ipairs(sorted_sounds) do
			table.insert(lines, ("%s %s"):format(template_key.encode(s[1]), s[2]))
		end
		table.insert(lines, "")
	end

	table.insert(lines, "# notes")
	table.insert(lines, self.sphLines:encode())
	table.insert(lines, "")

	return table.concat(lines, "\n")
end

---@param info table
---@return string
function Sph:getDefault(info)
	local out = {}

	table.insert(out, "# metadata")
	for k, v in pairs(info) do
		table.insert(out, k .. " " .. v)
	end
	table.insert(out, "preview 0")
	table.insert(out, "input 4key")

	table.insert(out, "")
	table.insert(out, "# notes")
	table.insert(out, "0000 =0")
	table.insert(out, "0000 =1")

	return table.concat(out, "\n")
end

return Sph
