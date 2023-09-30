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
function Sph:processLine(line)
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
		self.sphLines:processLine(line)
	end
end

---@param s string
function Sph:import(s)
	for _, line in ipairs(s:split("\n")) do
		self:processLine(line)
	end
	self.sphLines:updateTime()
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
