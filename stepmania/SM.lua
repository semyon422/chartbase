local SM = {}

local SM_metatable = {}
SM_metatable.__index = SM

SM.new = function(self)
	local sm = {}

	sm.header = {}
	sm.bpm = {}
	sm.stop = {}
	sm.charts = {}

	setmetatable(sm, SM_metatable)

	return sm
end

SM.newChart = function(self)
	local chart = {
		measure = 0,
		offset = 0,
		mode = 0,
		notes = {},
		linesPerMeasure = {},
		metaData = {},
	}
	self.chart = chart
	table.insert(self.charts, chart)
end

SM.import = function(self, noteChartString, path)
	self.path = path

	for _, line in ipairs(noteChartString:split("\n")) do
		self:processLine(line:trim())
	end
end

SM.processLine = function(self, line)
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
		table.insert(chart.metaData, line:match("^(.-):.*$"))
		if #chart.metaData == 5 then
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

SM.processHeaderLine = function(self, line)
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
		if value == "" then
			self.header[key] = self:findBackgroundFile()
		end
	end
end

SM.findBackgroundFile = function(self)
	local directory = self.path:match("(.*".."/"..")")
	local files = love.filesystem.getDirectoryItems(directory)
	
	for _, value in ipairs(files) do 
		local fileName = value:match("(.+)%..+"):lower()
		
		if fileName:find("bg") or fileName:find("background") then
			return value
		end
	end

	return ""
end

SM.processBPM = function(self, line)
	local tempoValues = line:split(",")
	for _, tempoValue in ipairs(tempoValues) do
		local beat, tempo = tempoValue:match("^(.+)=(.+)$")
		if beat and tempo then
			table.insert(
				self.bpm,
				{
					beat = tonumber(beat),
					tempo = tonumber(tempo)
				}
			)
			if not self.displayTempo then
				self.displayTempo = tonumber(tempo)
			end
		end
	end
end

SM.processSTOP = function(self, line)
	local stopValues = line:split(",")
	for _, stopValue in ipairs(stopValues) do
		local beat, duration = stopValue:match("^(.+)=(.+)$")
		if beat and duration then
			table.insert(
				self.stop,
				{
					beat = tonumber(beat),
					duration = tonumber(duration)
				}
			)
		end
	end
end

SM.processCommaLine = function(self)
	local chart = self.chart
	chart.measure = chart.measure + 1
	chart.offset = 0
end

SM.processNotesLine = function(self, line)
	local chart = self.chart
	if tonumber(line) then
		chart.mode = math.max(chart.mode, #line)
	end
	for i = 1, #line do
		local noteType = line:sub(i, i)
		if noteType ~= "0" then
			table.insert(
				chart.notes,
				{
					measure = chart.measure,
					offset = chart.offset,
					noteType = noteType,
					inputIndex = i
				}
			)
		end
	end
	chart.offset = chart.offset + 1
	chart.linesPerMeasure[chart.measure] = (chart.linesPerMeasure[chart.measure] or 0) + 1
end

return SM
