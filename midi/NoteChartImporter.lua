local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local MID = require("midi.MID")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	self.foregroundLayerDatas = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)
	
	return noteChartImporter
end

NoteChartImporter.import = function(self)
	local noteChart = NoteChart:new()
	noteChart.importer = self
	noteChart.metaData = MetaData:new()
	noteChart.metaData.noteChart = noteChart
	noteChart.inputMode:setInputCount("key", 88)
	noteChart.type = "midi"
	self.noteCharts = {noteChart}

	if not self.mid then
		self.mid = MID:new(self.content, self.path)
	end
	
	local hitsounds = love.filesystem.getDirectoryItems("userdata/hitsounds/midi")
	self.hitsoundFormat = hitsounds[1]:match("^.+(%..+)$")

	self.noteCount = 0
	self.length = 0
	self.firstNote = 0
	for i = 2, #self.mid.score do
		self:processData(i, self:createForegroundLayerData(i))
	end

	self.minTime = 0
	self.maxTime = self.length

	self:processMeasureLines()
	
	noteChart:compute()
	noteChart.index = 1
	noteChart.metaData:fillData()
end

NoteChartImporter.createForegroundLayerData = function(self, index)
	local index = index or #self.foregroundLayerDatas + 1

	local foregroundLayerData = self.noteCharts[1].layerDataSequence:requireLayerData(index)
	foregroundLayerData:setTimeMode("absolute")

	local tempoData = ncdk.TempoData:new(0, self.mid.bpm[1]["bpm"])
	foregroundLayerData:addTempoData(tempoData)

	local velocityData = ncdk.VelocityData:new(foregroundLayerData:getTimePoint(0, 1))
	velocityData.currentSpeed = tempoData.tempo
	foregroundLayerData:addVelocityData(velocityData)

	self.foregroundLayerDatas[index] = foregroundLayerData
	return foregroundLayerData
end

NoteChartImporter.processData = function(self, trackIndex, foregroundLayerData)
	local score = self.mid.score
	local noteChart = self.noteCharts[1]
	local constantVolume = self.settings and self.settings["midiConstantVolume"] or false
	local hitsoundFormat = self.hitsoundFormat
	local noteCount = self.noteCount

	local hitsoundPath
	local startTimePoint
	local startNoteData
	local endTimePoint
	local endNoteData

	local firstNote = true
	for _, event in ipairs(score[trackIndex]) do
		if event[1] == "note" then
			hitsoundPath = tostring(event[5] - 20) .. hitsoundFormat

			startTimePoint = foregroundLayerData:getTimePoint(event[2] / 1000, 1)
			startNoteData = ncdk.NoteData:new(startTimePoint)
			startNoteData.inputType = "key"
			startNoteData.inputIndex = event[5] - 20
			startNoteData.sounds = {{hitsoundPath, constantVolume and 1 or event[6] / 127}}
			startNoteData.noteType = "LongNoteStart"

			endTimePoint = foregroundLayerData:getTimePoint((event[2] + event[3]) / 1000, 1)
			endNoteData = ncdk.NoteData:new(endTimePoint)
			endNoteData.inputType = startNoteData.inputType
			endNoteData.inputIndex = startNoteData.inputIndex
			endNoteData.noteType = "LongNoteEnd"
			endNoteData.sounds = {{"none" .. hitsoundFormat, 0}}

			startNoteData.endNoteData = endNoteData
			endNoteData.startNoteData = startNoteData

			foregroundLayerData:addNoteData(startNoteData)
			foregroundLayerData:addNoteData(endNoteData)

			noteChart:addResource("sound", hitsoundPath, {hitsoundPath})

			noteCount = noteCount + 1

			if firstNote then
				firstNote = false
				if self.firstNote == 0 or startTimePoint.absoluteTime < self.firstNote then
					self.firstNote = startTimePoint.absoluteTime
				end
			end
		end
	end

	if endTimePoint and endTimePoint.absoluteTime > self.length then
		self.length = endTimePoint.absoluteTime
	end

	self.noteCount = noteCount
end

NoteChartImporter.processMeasureLines = function(self)
	local foregroundLayerData = self:createForegroundLayerData(1)

	local time = self.firstNote

	local currentBpm = 1
	local bpmChange
	local SecondsPerMeasure

	while time < self.length do
		bpmChange = self.mid.bpm[currentBpm+1] and self.mid.bpm[currentBpm+1]["dt"] or self.length
		SecondsPerMeasure = 1 / ((self.mid.bpm[currentBpm]["bpm"] / 4) / 60)

		while time < bpmChange do
			local timePoint = foregroundLayerData:getTimePoint(time, 1)
			
			local startNoteData = ncdk.NoteData:new(timePoint)
			startNoteData.inputType = "measure"
			startNoteData.inputIndex = 1
			startNoteData.noteType = "LineNoteStart"
			foregroundLayerData:addNoteData(startNoteData)
			
			local endNoteData = ncdk.NoteData:new(timePoint)
			endNoteData.inputType = "measure"
			endNoteData.inputIndex = 1
			endNoteData.noteType = "LineNoteEnd"
			foregroundLayerData:addNoteData(endNoteData)
			
			startNoteData.endNoteData = endNoteData
			endNoteData.startNoteData = startNoteData

			time = time + SecondsPerMeasure
		end

		time = bpmChange
		currentBpm = currentBpm + 1
	end
end

return NoteChartImporter
