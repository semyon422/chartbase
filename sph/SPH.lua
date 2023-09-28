local class = require("class")
local InputMode = require("ncdk.InputMode")
local SphLines = require("sph.SphLines")

---@class sph.SPH
---@operator call: sph.SPH
local SPH = class()

function SPH:new()
	self.metadata = {}
	self.sphLines = SphLines()
end

---@param s string
function SPH:import(s)
	local headers = true
	for _, line in ipairs(s:split("\n")) do
		if line == "" and headers then
			headers = false
			self.inputMode = InputMode(self.metadata.input)
			self.columns = self.inputMode:getColumns()
			self.inputMap = self.inputMode:getInputMap()
			self.sphLines.columns = self.columns
		elseif headers then
			local k, v = line:match("^(.-)=(.*)$")
			self.metadata[k] = v
		elseif line ~= "" then
			self.sphLines:processLine(line)
		end
	end
	self.sphLines:updateTime()
end

local defaultChart = [[
title=title
artist=artist
name=name
creator=creator
source=
level=0
tags=
audio=audio.mp3
background=background.jpg
bpm=100
preview=0
input=4key

0000=0
0000=1
]]

---@param info table
---@return string
function SPH:getDefault(info)
	local chart = defaultChart
	for k, v in pairs(info) do
		chart = chart:gsub(k .. "=[^\n]*\n", k .. "=" .. v .. "\n")
	end
	return chart
end

return SPH
