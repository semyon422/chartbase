local ncdk = require("ncdk")
local NoteDataImporter = require("osu.NoteDataImporter")
local TimingDataImporter = require("osu.TimingDataImporter")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}
	
	noteChartImporter.metaData = {}
	
	setmetatable(noteChartImporter, NoteChartImporter_metatable)
	
	return noteChartImporter
end

NoteChartImporter.import = function(self, noteChartString)
	self.foregroundLayerData = self.noteChart.layerDataSequence:requireLayerData(1)
	self.backgroundLayerData = self.noteChart.layerDataSequence:requireLayerData(2)
	self.backgroundLayerData.invisible = true
	
	self.foregroundLayerData.timeData:setMode(ncdk.TimeData.Modes.Absolute)
	self.backgroundLayerData.timeData:setMode(ncdk.TimeData.Modes.Absolute)
	
	self.noteChartString = noteChartString
	self:stage1_process()
	self:stage2_process()
	
	self.noteChart.inputMode:setInputCount("key", self.metaData.CircleSize)
	self.noteChart.type = "osu"
	
	self.noteChart:compute()
end

NoteChartImporter.stage1_process = function(self)
	self.metaData = {}
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}
	
	self.totalLength = 0
	
	for _, line in ipairs(self.noteChartString:split("\n")) do
		self:processLine(line)
	end
	
	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)
	
	self.foregroundLayerData:updateZeroTimePoint()
	self.backgroundLayerData:updateZeroTimePoint()
	
	self:updatePrimaryBPM()
	self:processMeasureLines()
	
	self:processAudio()
end

local compareTdi = function(a, b)
	if a.startTime == b.startTime then
		return a.timingChange and a.timingChange ~= b.timingChange
	else
		return a.startTime < b.startTime
	end
end
NoteChartImporter.processTimingDataImporters = function(self)
	local redTimingData = {}
	local greenTimingData = {}
	
	for i = #self.tempTimingDataImporters, 1, -1 do
		local tdi = self.tempTimingDataImporters[i]
		if tdi.timingChange and not redTimingData[tdi.offset] then
			redTimingData[tdi.offset] = tdi
		elseif not tdi.timingChange and not greenTimingData[tdi.offset] then
			greenTimingData[tdi.offset] = tdi
		end
	end
	
	for _, timingDataImporter in pairs(redTimingData) do
		table.insert(self.timingDataImporters, timingDataImporter)
	end
	
	for _, timingDataImporter in pairs(greenTimingData) do
		table.insert(self.timingDataImporters, timingDataImporter)
	end
	
	table.sort(self.timingDataImporters, compareTdi)
end

NoteChartImporter.updatePrimaryBPM = function(self)
	local lastTime = self.totalLength
	local currentBeatLength = 0
	local bpmDurations = {}
	
	for i = #self.timingDataImporters, 1, -1 do
		local tdi = self.timingDataImporters[i]
		
		if tdi.timingChange then
			currentBeatLength = tdi.beatLength
		end
		
		if not (currentBeatLength == 0 or tdi.offset > lastTime or (not tdi.timingChange and i > 1)) then
			bpmDurations[currentBeatLength] = bpmDurations[currentBeatLength] or 0
			bpmDurations[currentBeatLength] = bpmDurations[currentBeatLength] + (lastTime - (i == 1 and 0 or tdi.offset))
			
			lastTime = tdi.offset
		end
	end
	
	local longestDuration = 0
	local average = 0
	
	for beatLength, duration in pairs(bpmDurations) do
		if duration > longestDuration then
			longestDuration = duration
			average = beatLength
		end
	end
	
	self.primaryBeatLength = average
	self.primaryBPM = 60000 / average
end

NoteChartImporter.processAudio = function(self)
	local audioFileName = self.metaData["AudioFilename"]
	
	if audioFileName and audioFileName ~= "virtual" then
		local timePoint = self.backgroundLayerData:getZeroTimePoint()
		
		timePoint.velocityData = self.backgroundLayerData:getVelocityDataByTimePoint(timePoint)
		
		noteData = ncdk.NoteData:new(timePoint)
		noteData.inputType = "auto"
		noteData.inputIndex = 0
		noteData.sounds = {audioFileName}
		self.noteChart:addResource("sound", audioFileName)
		
		noteData.zeroClearVisualStartTime = self.backgroundLayerData:getVisualTime(timePoint, self.backgroundLayerData:getZeroTimePoint(), true)
		noteData.currentVisualStartTime = noteData.zeroClearVisualStartTime
	
		noteData.noteType = "SoundNote"
		self.backgroundLayerData:addNoteData(noteData)
	end
end

NoteChartImporter.processVelocityData = function(self)
	local currentBeatLength = self.primaryBeatLength
	
	local rawVelocity = {}
	for i = 1, #self.timingDataImporters do
		local tdi = self.timingDataImporters[i]
		
		rawVelocity[tdi.offset] = rawVelocity[tdi.offset] or 1
		
		if tdi.timingChange then
			currentBeatLength = tdi.beatLength
			rawVelocity[tdi.offset]
				= self.primaryBeatLength
				/ currentBeatLength
		else
			rawVelocity[tdi.offset]
				= tdi.velocity
				* self.primaryBeatLength
				/ currentBeatLength
		end
	end
	
	for offset, value in pairs(rawVelocity) do
		local timePoint = self.foregroundLayerData:getTimePoint(offset / 1000)
		local velocityData = ncdk.VelocityData:new(
			timePoint,
			ncdk.Fraction:new():fromNumber(value, 1000)
		)
		self.foregroundLayerData:addVelocityData(velocityData)
	end
	
	self.foregroundLayerData.spaceData.velocityDataSequence:sort()
end

NoteChartImporter.stage2_process = function(self)
	self:processVelocityData()
	
	for _, noteParser in ipairs(self.noteDataImporters) do
		self.foregroundLayerData:addNoteData(noteParser:getNoteData())
	end
	self.foregroundLayerData.noteDataSequence:sort()
end

NoteChartImporter.processLine = function(self, line)
	if line:find("^%[") then
		self.currentBlockName = line:match("^%[(.+)%]")
	else
		if line:find("^%a+:.*$") then
			local key, value = line:match("^(%a+):%s?(.*)")
			self.metaData[key] = value:trim()
			self.noteChart:hashSet(key, value:trim())
		elseif self.currentBlockName == "TimingPoints" and line:find("^.+,.+,.+,.+,.+,.+,.+,.+$") then
			self:stage1_addTimingPointParser(line)
		elseif self.currentBlockName == "Events" and (
				line:find("^5,.+,.+,\".+\",.+$") or
				line:find("^Sample,.+,.+,\".+\",.+$")
			)
		then
			self:stage1_addNoteParser(line, true)
		elseif self.currentBlockName == "Events" and line:find("^0,.+,\".+\",.+$") then
			local path = line:match("^0,.+,\"(.+)\",.+$")
			self.noteChart:hashSet("Background", path)
		elseif self.currentBlockName == "HitObjects" and line:trim() ~= "" then
			self:stage1_addNoteParser(line)
		end
	end
end

NoteChartImporter.stage1_addTimingPointParser = function(self, line)
	local timingDataImporter = TimingDataImporter:new(line)
	timingDataImporter.line = line
	timingDataImporter.noteChartImporter = self
	timingDataImporter:init()
	
	table.insert(self.tempTimingDataImporters, timingDataImporter)
end

NoteChartImporter.stage1_addNoteParser = function(self, line, event)
	local noteDataImporter = NoteDataImporter:new()
	noteDataImporter.line = line
	noteDataImporter.noteChartImporter = self
	noteDataImporter.noteChart = self.noteChart
	if not event then
		noteDataImporter:init()
	else
		noteDataImporter:initEvent()
	end
	
	table.insert(self.noteDataImporters, noteDataImporter)
end

NoteChartImporter.processMeasureLines = function(self)
	local currentTime = 0
	local offset
	local firstTdi
	for i = 1, #self.timingDataImporters do
		local tdi = self.timingDataImporters[i]
		if tdi.timingChange then
			firstTdi = tdi
			offset = firstTdi.offset
			break
		end
	end
	while true do
		if offset - firstTdi.measureLength <= 0 then
			break
		else
			offset = offset - firstTdi.measureLength
		end
	end
	
	local lines = {}
	for i = 1, #self.timingDataImporters do
		local currentTdi = self.timingDataImporters[i]
		if currentTdi.timingChange then
			local nextTdi
			for j = i + 1, #self.timingDataImporters do
				if self.timingDataImporters[j].timingChange then
					nextTdi = self.timingDataImporters[j]
					break
				end
			end
			
			local nextLastTime = nextTdi and nextTdi.offset - 1 or self.totalLength
			
			while true do
				if offset < nextLastTime then
					table.insert(lines, offset)
					offset = offset + currentTdi.measureLength
				else
					offset = nextLastTime + 1
					break
				end
			end
		end
	end
	
	for _, startTime in ipairs(lines) do
		local measureTime = ncdk.Fraction:new(measureIndex)
		local timePoint = self.foregroundLayerData:getTimePoint(startTime / 1000)
		
		local startNoteData = ncdk.NoteData:new(timePoint)
		startNoteData.inputType = "measure"
		startNoteData.inputIndex = 1
		startNoteData.noteType = "LineNoteStart"
		self.foregroundLayerData:addNoteData(startNoteData)
		
		local endNoteData = ncdk.NoteData:new(timePoint)
		endNoteData.inputType = "measure"
		endNoteData.inputIndex = 1
		endNoteData.noteType = "LineNoteEnd"
		self.foregroundLayerData:addNoteData(endNoteData)
		
		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData
	end
end

return NoteChartImporter
