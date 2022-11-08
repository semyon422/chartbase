local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local Osu = require("osu.Osu")
local NoteDataImporter = require("osu.NoteDataImporter")
local TimingDataImporter = require("osu.TimingDataImporter")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self)
	self.noteChart = NoteChart:new()
	local noteChart = self.noteChart

	if not self.osu then
		self.osu = Osu:new()
		self.osu:import(self.content:gsub("\r\n", "\n"))
	end

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("absolute")

	self:process()

	local mode = self.osu.mode
	if mode == 0 then
		noteChart.inputMode.osu = 1
	elseif mode == 1 then
		noteChart.inputMode.taiko = 1
	elseif mode == 2 then
		noteChart.inputMode.fruits = 1
	elseif mode == 3 then
		noteChart.inputMode.key = math.floor(self.osu.keymode)
	end
	noteChart.type = "osu"
	noteChart:compute()
	noteChart.index = 1
	noteChart.metaData = MetaData(noteChart, self)

	self.noteCharts = {noteChart}
end

NoteChartImporter.process = function(self)
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}

	self.noteCount = 0

	for _, event in ipairs(self.osu.events) do
		self:addNoteParser(event, true)
	end

	for _, tp in ipairs(self.osu.timingPoints) do
		self:addTimingPointParser(tp)
	end

	for _, note in ipairs(self.osu.hitObjects) do
		self:addNoteParser(note)
	end

	self:updateLength()

	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)

	self:updatePrimaryBPM()

	self:processMeasureLines()

	self.audioFileName = self.osu.metadata["AudioFilename"]
	self:processAudio()
	self:processTimingPoints()

	for _, noteParser in ipairs(self.noteDataImporters) do
		self.foregroundLayerData:addNoteData(noteParser:getNoteData())
	end
end

NoteChartImporter.updateLength = function(self)
	self.minTime = self.minTime or 0
	self.maxTime = self.maxTime or 0
	self.totalLength = self.maxTime - self.minTime
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
	local lastTime = self.maxTime
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

	if longestDuration == 0 then
		self.primaryBeatLength = 0
		self.primaryBPM = 0
		return
	end

	self.primaryBeatLength = average
	self.primaryBPM = 60000 / average
end

NoteChartImporter.processAudio = function(self)
	local audioFileName = self.audioFileName

	if audioFileName and audioFileName ~= "virtual" then
		local timePoint = self.foregroundLayerData:getTimePoint(0, -1)

		local noteData = ncdk.NoteData:new(timePoint)
		noteData.inputType = "auto"
		noteData.inputIndex = 0
		noteData.sounds = {{audioFileName, 1}}
		noteData.stream = true
		self.noteChart:addResource("sound", audioFileName, {audioFileName})

		noteData.noteType = "SoundNote"
		self.foregroundLayerData:addNoteData(noteData)
	end
end

NoteChartImporter.processTimingPoints = function(self)
	local currentBeatLength = self.primaryBeatLength

	local timingState = {}
	for i = 1, #self.timingDataImporters do
		local tdi = self.timingDataImporters[i]

		timingState[tdi.startTime] = timingState[tdi.startTime] or {}

		if tdi.timingChange then
			currentBeatLength = tdi.beatLength
			local data = timingState[tdi.startTime]
			data.isTempo = true
			data.clearSpeed = 1
			data.modifiedSpeed = self.primaryBeatLength / currentBeatLength
			data.beatLength = tdi.beatLength
		else
			local data = timingState[tdi.startTime]
			data.isVelocity = true
			data.clearSpeed = tdi.velocity
			data.modifiedSpeed = tdi.velocity * self.primaryBeatLength / currentBeatLength
		end
	end

	for offset, data in pairs(timingState) do
		local time = offset / 1000
		local timePoint = self.foregroundLayerData:getTimePoint(time, 1)

		local velocityData = ncdk.VelocityData:new(timePoint)
		velocityData.currentSpeed = data.modifiedSpeed
		velocityData.clearCurrentSpeed = data.clearSpeed
		velocityData.sv = data.isVelocity
		self.foregroundLayerData:addVelocityData(velocityData)

		if data.isTempo then
			local tempoData = ncdk.TempoData:new(time, 60000 / data.beatLength)
			self.foregroundLayerData:addTempoData(tempoData)
		end
	end
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

	if offset > 0 then
		while true do
			if offset - firstTdi.measureLength <= 0 then
				break
			else
				offset = offset - firstTdi.measureLength
			end
		end
	elseif offset < 0 then
		offset = offset + math.floor(-offset / firstTdi.measureLength) * firstTdi.measureLength
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

			local nextLastTime = math.min(nextTdi and nextTdi.startTime - 1 or self.maxTime, self.maxTime)
			while true do
				if offset < nextLastTime then
					table.insert(lines, offset)
					offset = offset + math.max(1, currentTdi.measureLength)
				else
					offset = nextLastTime + 1
					break
				end
			end
		end
	end

	for _, startTime in ipairs(lines) do
		local timePoint = self.foregroundLayerData:getTimePoint(startTime / 1000, 1)

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
