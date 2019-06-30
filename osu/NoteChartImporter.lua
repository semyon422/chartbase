local ncdk = require("ncdk")
local Osu = require("osu.Osu")
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
	if not self.osu then
		self.osu = Osu:new()
		self.osu:import(noteChartString)
	end
	
	self.foregroundLayerData = self.noteChart.layerDataSequence:requireLayerData(1)
	self.foregroundLayerData:setTimeMode("absolute")
	
	self:process()
	
	self.noteChart.inputMode:setInputCount("key", self.noteChart:hashGet("CircleSize"))
	self.noteChart.type = "osu"
	
	self.noteChart:compute()
end

NoteChartImporter.process = function(self)
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}
	
	self.noteCount = 0
	self.maxTime = 0
	self.minTime = 0
	
	for key, value in pairs(self.osu.metadata) do
		self.noteChart:hashSet(key, value:trim())
	end
	
	self.noteChart:hashSet("Background", self.osu.background)
	for _, event in ipairs(self.osu.events) do
		self:addNoteParser(event, true)
	end
	
	for _, tp in ipairs(self.osu.timingPoints) do
		self:addTimingPointParser(tp)
	end
	
	for _, note in ipairs(self.osu.hitObjects) do
		self:addNoteParser(note)
	end
	
	
	self.totalLength = self.maxTime - self.minTime
	self.noteChart:hashSet("totalLength", self.totalLength)
	self.noteChart:hashSet("noteCount", self.noteCount)
	
	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)
	
	self.foregroundLayerData:updateZeroTimePoint()
	
	self:updatePrimaryBPM()
	self.noteChart:hashSet("primaryBPM", self.primaryBPM)
	
	self:processMeasureLines()
	
	self.audioFileName = self.noteChart:hashGet("AudioFilename")
	self:processAudio()
	self:processVelocityData()
	
	for _, noteParser in ipairs(self.noteDataImporters) do
		self.foregroundLayerData:addNoteData(noteParser:getNoteData())
	end
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
		if tdi.timingChange and not redTimingData[tdi.startTime] then
			redTimingData[tdi.startTime] = tdi
		elseif not tdi.timingChange and not greenTimingData[tdi.startTime] then
			greenTimingData[tdi.startTime] = tdi
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
		
		if not (currentBeatLength == 0 or tdi.startTime > lastTime or (not tdi.timingChange and i > 1)) then
			bpmDurations[currentBeatLength] = bpmDurations[currentBeatLength] or 0
			bpmDurations[currentBeatLength] = bpmDurations[currentBeatLength] + (lastTime - (i == 1 and 0 or tdi.startTime))
			
			lastTime = tdi.startTime
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
	local audioFileName = self.audioFileName
	
	if audioFileName and audioFileName ~= "virtual" then
		local timePoint = self.foregroundLayerData:getZeroTimePoint()
		
		local noteData = ncdk.NoteData:new(timePoint)
		noteData.inputType = "auto"
		noteData.inputIndex = 0
		noteData.sounds = {{audioFileName, 1}}
		self.noteChart:addResource("sound", audioFileName)
		
		noteData.noteType = "SoundNote"
		self.foregroundLayerData:addNoteData(noteData)
	end
end

NoteChartImporter.processVelocityData = function(self)
	local currentBeatLength = self.primaryBeatLength
	
	local rawVelocity = {}
	for i = 1, #self.timingDataImporters do
		local tdi = self.timingDataImporters[i]
		
		rawVelocity[tdi.startTime] = rawVelocity[tdi.startTime] or 1
		
		if tdi.timingChange then
			currentBeatLength = tdi.beatLength
			rawVelocity[tdi.startTime]
				= self.primaryBeatLength
				/ currentBeatLength
		else
			rawVelocity[tdi.startTime]
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

NoteChartImporter.addTimingPointParser = function(self, tp)
	local timingDataImporter = TimingDataImporter:new(tp)
	timingDataImporter.noteChartImporter = self
	timingDataImporter:init()
	
	table.insert(self.tempTimingDataImporters, timingDataImporter)
end

NoteChartImporter.addNoteParser = function(self, note, event)
	local noteDataImporter = NoteDataImporter:new(note)
	noteDataImporter.noteChartImporter = self
	noteDataImporter.noteChart = self.noteChart
	if not event then
		noteDataImporter:init()
		self.noteCount = self.noteCount + 1
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
			offset = firstTdi.startTime
			break
		end
	end
	if not firstTdi then
		return
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
			
			local nextLastTime = nextTdi and nextTdi.startTime - 1 or self.totalLength
			
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
