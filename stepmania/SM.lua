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

---@param noteChartString string
---@param path string
function SM:import(noteChartString, path)
	self.path = path

	for _, line in ipairs(noteChartString:split("\n")) do
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
	elseif key == "BACKGROUND" then
		self:processBackground(value)
	end
end

---@param fileName string
function SM:processBackground(fileName)
	if not love then
		self.header["BACKGROUND"] = ""
		return
	end
	local fs = love.filesystem

	local getComparable = function(fileName)
		local fileName = fileName:lower()

		if not fileName:find("%.") then
			return fileName
		end

		return fileName:match("(.+)%..+")
	end

	local isImage = function(fileName)
		local imageFormats = {".jpg", ".jpeg", ".png", ".bmp", ".tga"}
		local fileExtension = fileName:match("^.+(%..+)$")

		for _, format in ipairs(imageFormats) do
			if format == fileExtension then
				return true
			end
		end

		return false
	end

	local directory = self.path:match("(.*".."/"..")")
	local exists = fs.getInfo(directory .. fileName)

	if fileName ~= "" and exists then
		self.header["BACKGROUND"] = fileName
		return
	end

	local dirFiles = fs.getDirectoryItems(directory)
	local possibleNames = {"background", "bg"}

	if fileName ~= "" then
		table.insert(possibleNames, 1, getComparable(fileName))
	end

	for _, itemName in ipairs(dirFiles) do
		local comparable = getComparable(itemName)

		for _, name in ipairs(possibleNames) do
			if comparable:find(name) then
				if isImage(itemName) then
					self.header["BACKGROUND"] = itemName
					return
				end
			end
		end
	end

	self.header["BACKGROUND"] = ""
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
				inputIndex = i
			})
		end
	end
	chart.offset = chart.offset + 1
	chart.linesPerMeasure[chart.measure] = (chart.linesPerMeasure[chart.measure] or 0) + 1
end

return SM
