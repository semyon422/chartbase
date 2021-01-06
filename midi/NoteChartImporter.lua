local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local MID = require("midi.MID")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	-- index 1 is measureline
	-- 2..* indexes are tracks
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

	self.title = self.path:match("^.*/(.*).mid$")

	if not self.mid then
		self.mid = MID:new(self.content)
	end
	
	local hitsounds = love.filesystem.getDirectoryItems("userdata/hitsounds/midi")
	self.hitsoundFormat = hitsounds[1]:match("^.+(%..+)$") -- .ogg for example

	self.noteCount = 0
	self.firstNote = 0 -- time of the first note
	self.length = 0 -- time of the last note
	for i = 2, #self.mid.score do -- go through tracks
		self:processData(i, self:createForegroundLayerData(i))
	end

	self.minTime = 0
	self.maxTime = self.length

	self:processMeasureLines()
	
	noteChart:compute()
	noteChart.index = 1
	noteChart.metaData:fillData()
end

-- create a new ForegroundLayerData
-- set the TimeMode, TempoData and VelocityData
-- add it to self.foregroundLayerDatas
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

	local checkFirstNote = true
	for _, event in ipairs(score[trackIndex]) do
		if event[1] == "note" then
			hitsoundPath = tostring(event[5] - 20) .. hitsoundFormat -- - 20 because the event goes from 21 to 108 instead of 1 to 88

			startTimePoint = foregroundLayerData:getTimePoint(event[2] / 1000, 1)
			startNoteData = ncdk.NoteData:new(startTimePoint)
			startNoteData.inputType = "key"
			startNoteData.inputIndex = event[5] - 20
			startNoteData.sounds = {{hitsoundPath, constantVolume and 1 or event[6] / 127}} -- / 127 because the event goes from 0 to 127 instead of 1 based
			startNoteData.noteType = "LongNoteStart"

			endTimePoint = foregroundLayerData:getTimePoint((event[2] + event[3]) / 1000, 1) -- (event time + event duration) / 1000
			endNoteData = ncdk.NoteData:new(endTimePoint)
			endNoteData.inputType = startNoteData.inputType
			endNoteData.inputIndex = startNoteData.inputIndex
			endNoteData.sounds = {{"none" .. hitsoundFormat, 0}}
			endNoteData.noteType = "LongNoteEnd"

			startNoteData.endNoteData = endNoteData
			endNoteData.startNoteData = startNoteData

			foregroundLayerData:addNoteData(startNoteData)
			foregroundLayerData:addNoteData(endNoteData)

			noteChart:addResource("sound", hitsoundPath, {hitsoundPath})

			noteCount = noteCount + 1

			-- check if the startTimePoint time is less than the current self.firstNote time
			if checkFirstNote then
				checkFirstNote = false -- only check once in this for loop
				if self.firstNote == 0 or startTimePoint.absoluteTime < self.firstNote then
					self.firstNote = startTimePoint.absoluteTime
				end
			end
		end
	end

	-- check if last note's endTimePoint time is more than current self.length time
	if endTimePoint and endTimePoint.absoluteTime > self.length then
		self.length = endTimePoint.absoluteTime
	end

	self.noteCount = noteCount
end

-- fill first ForegroundLayerData with measure lines
-- only measure lines need to account for bpm changes, because to_millisecs calculates it for the notes
NoteChartImporter.processMeasureLines = function(self)
	local foregroundLayerData = self:createForegroundLayerData(1)

	local time = self.firstNote

	local currentBpm = 1
	local bpmChange -- when to change to a new bpm
	local SecondsPerMeasure -- duration between measure lines

	-- add measure lines untill the end of the chart
	while time < self.length do
		-- change to new bpm
		bpmChange = self.mid.bpm[currentBpm+1] and self.mid.bpm[currentBpm+1]["dt"] or self.length
		SecondsPerMeasure = 1 / ((self.mid.bpm[currentBpm]["bpm"] / 4) / 60)

		-- add measure lines untill it's time for a new bpm
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
