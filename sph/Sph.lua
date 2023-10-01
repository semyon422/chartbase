local class = require("class")
local SphLines = require("sph.SphLines")

---@class sph.Sph
---@operator call: sph.Sph
local Sph = class()

function Sph:new()
	self.metadata = {}
	self.templates = {}
	self.sphLines = SphLines()
	self.section = ""
end

---@param line string
function Sph:decodeLine(line)
	if line == "" then
		return
	end

	if line:sub(1, 1) == "#" then
		self.section = line:match("^# (.+)$")
	elseif self.section == "metadata" then
		local k, v = line:match("^(%w+) (.+)$")
		if k then
			self.metadata[k] = v
		end
	elseif self.section == "templates" then
		local t, k, v = line:match("^(%w+) (%w+) (.+)$")
		if t then
			self.templates[t] = self.templates[t] or {}
			self.templates[t][k] = self.templates[t][k] or {}
			table.insert(self.templates[t][k], v)
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

	local templates = self.templates
	if #templates > 0 then
		table.insert(lines, "# templates")
		for t, k in pairs(templates) do
			for _, v in ipairs(k) do
				table.insert(lines, ("%s %s %s"):format(t, k, v))
			end
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

	for k, v in pairs(info) do
		table.insert(out, k .. " " .. v)
	end
	table.insert(out, "0000 =0")
	table.insert(out, "0000 =1")

	return table.concat(out, "\n")
end

return Sph
