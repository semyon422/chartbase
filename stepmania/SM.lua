local class = require("class")

---@class stepmania.SM
---@operator call: stepmania.SM
local SM = class()

function SM:new()
	self.header = {}
	self.bpm = {}
	self.stop = {}
	self.charts = {}
end

function SM:newChart()
	local chart = {
		measure = 0,
		offset = 0,
		mode = 0,
		notes = {},
		linesPerMeasure = {},
		header = {},
	}
	self.chart = chart
	table.insert(self.charts, chart)
end

local BOM = string.char(0xEF, 0xBB, 0xBF)

---@param s string
function SM:import(s)
	if s:sub(1, 3) == BOM then
		s = s:sub(4)
	end
	for _, line in ipairs(s:split("\n")) do
		self:processLine(line:trim())
	end
end

---@param line string
function SM:processLine(line)
	local chart = self.chart
	if self.parsingBpm then
		self:processBPM(line)
		if line:find(";") then
			self.parsingBpm = false
		end
		return
	end
	if self.parsingStop then
		self:processSTOP(line)
		if line:find(";") then
			self.parsingStop = false
		end
		return
	end
	if line:find("^#NOTES") then
		self.parsingNotes = true
		self.parsingNotesMetaData = true
		self:newChart()
	elseif self.parsingNotesMetaData then
		table.insert(chart.header, line:match("^(.-):.*$"))
		if #chart.header == 5 then
			self.parsingNotesMetaData = false
		end
	elseif self.parsingNotes and not line:find(",") and line:find("//") then
		return
	elseif self.parsingNotes and line:find("^[^,^;]+$") then
		self.parsingNotesMetaData = false
		self:processNotesLine(line)
	elseif self.parsingNotes and line:find("^,.*$") then
		self:processCommaLine()
	elseif self.parsingNotes and line:find("^;.*$") then
		self.parsingNotes = false
	elseif line:find("#%S+:.*") then
		self:processHeaderLine(line)
	end
end

---@param line string
function SM:processHeaderLine(line)
	local key, value = line:match("^#(%S+):(.*);$")
	if not key then
		key, value = line:match("^#(%S+):(.*)$")
	end
	key = key:upper()
	self.header[key] = value

	if key == "BPMS" then
		self:processBPM(value)
		if not line:find(";") then
			self.parsingBpm = true
		end
	elseif key == "STOPS" then
		self:processSTOP(value)
		if not line:find(";") then
			self.parsingStop = true
		end
	end
end

---@param line string
function SM:processBPM(line)
	local tempoValues = line:gsub(";", ""):split(",")
	for _, tempoValue in ipairs(tempoValues) do
		local beat, tempo = tempoValue:match("^(.+)=(.+)$")
		if beat and tempo then
			table.insert(self.bpm, {
				beat = tonumber(beat),
				tempo = tonumber(tempo)
			})
			if not self.displayTempo then
				self.displayTempo = tonumber(tempo)
			end
		end
	end
end

---@param line string
function SM:processSTOP(line)
	local stopValues = line:gsub(";", ""):split(",")
	for _, stopValue in ipairs(stopValues) do
		local beat, duration = stopValue:match("^(.+)=(.+)$")
		if beat and duration then
			table.insert(self.stop, {
				beat = tonumber(beat),
				duration = tonumber(duration)
			})
		end
	end
end

function SM:processCommaLine()
	local chart = self.chart
	chart.measure = chart.measure + 1
	chart.offset = 0
end

---@param line string
function SM:processNotesLine(line)
	local chart = self.chart
	if tonumber(line) then
		chart.mode = math.max(chart.mode, #line)
	end
	for i = 1, #line do
		local noteType = line:sub(i, i)
		if noteType ~= "0" then
			table.insert(chart.notes, {
				measure = chart.measure,
				offset = chart.offset,
				noteType = noteType,
				column = i,
			})
		end
	end
	chart.offset = chart.offset + 1
	chart.linesPerMeasure[chart.measure] = (chart.linesPerMeasure[chart.measure] or 0) + 1
end

return SM
