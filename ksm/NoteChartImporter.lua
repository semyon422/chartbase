local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local Ksh = require("ksm.Ksh")
local bmsNoteChartImporter = require("bms.NoteChartImporter")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	noteChartImporter.primaryTempo = 120
	noteChartImporter.measureCount = 0

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self, noteChartString)
	self.noteChart = NoteChart:new()
	local noteChart = self.noteChart

	if not self.ksh then
		self.ksh = Ksh:new()
		self.ksh:import(self.content:gsub("\r\n", "\n"))
	end

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")
	self.foregroundLayerData:setSignatureMode("long")
	self.foregroundLayerData:setPrimaryTempo(120)

	self.backgroundLayerData = noteChart:getLayerData(2)
	self.backgroundLayerData:setTimeMode("absolute")
	self.backgroundLayerData:setSignatureMode("long")
	self.backgroundLayerData:setPrimaryTempo(120)

	self:processData()

	self.measureCount = #self.ksh.measureStrings
	self:processMeasureLines()

	noteChart.inputMode.bt = 4
	noteChart.inputMode.fx = 2
	noteChart.inputMode.laserleft = 2
	noteChart.inputMode.laserright = 2
	noteChart.type = "ksm"

	noteChart:compute()

	self:updateLength()

	local audio = self.ksh.options.m
	local split = audio:split(";")
	if split[1] then
		self.audioFileName = split[1]
	else
		self.audioFileName = audio
	end
	self:processAudio()

	noteChart.index = 1
	noteChart.metaData = MetaData(noteChart, self)

	self.noteCharts = {noteChart}
end

NoteChartImporter.updateLength = bmsNoteChartImporter.updateLength

NoteChartImporter.processAudio = function(self)
	local audioFileName = self.audioFileName

	if audioFileName then
		local startTime = -(tonumber(self.ksh.options.o) or 0) / 1000
		local timePoint = self.backgroundLayerData:getTimePoint(startTime)

		local noteData = ncdk.NoteData:new(timePoint)
		noteData.sounds = {{audioFileName, 1}}
		self.noteChart:addResource("sound", audioFileName, {audioFileName})

		noteData.noteType = "SoundNote"
		self.backgroundLayerData:addNoteData(noteData, "auto", 0)
	end
end

NoteChartImporter.processData = function(self)
	self.noteCount = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil

	local ld = self.foregroundLayerData

	for _, tempoData in ipairs(self.ksh.tempos) do
		local measureTime = ncdk.Fraction:new(tempoData.lineOffset, tempoData.lineCount) + tempoData.measureOffset
		ld:insertTempoData(measureTime, tempoData.tempo)
	end

	for _, signatureData in ipairs(self.ksh.timeSignatures) do
		ld:setSignature(
			signatureData.measureIndex,
			ncdk.Fraction:new(signatureData.n * 4, signatureData.d)
		)
	end

	local allNotes = {}
	for _, note in ipairs(self.ksh.notes) do
		allNotes[#allNotes + 1] = note
	end
	for _, laser in ipairs(self.ksh.lasers) do
		allNotes[#allNotes + 1] = laser
	end

	for _, _noteData in ipairs(allNotes) do
		local startMeasureTime = ncdk.Fraction:new(_noteData.startLineOffset, _noteData.startLineCount) + _noteData.startMeasureOffset
		local startTimePoint = ld:getTimePoint(startMeasureTime)

		local startNoteData = ncdk.NoteData:new(startTimePoint)
		local inputType = _noteData.input
		local inputIndex = _noteData.lane
		if inputType == "fx" then
			inputIndex = _noteData.lane - 4
		end

		startNoteData.sounds = {}

		ld:addNoteData(startNoteData, inputType, inputIndex)

		local lastTimePoint = startTimePoint
		local endMeasureTime = ncdk.Fraction:new(_noteData.endLineOffset, _noteData.endLineCount) + _noteData.endMeasureOffset

		if startMeasureTime == endMeasureTime then
			startNoteData.noteType = "ShortNote"
		else
			if _noteData.input ~= "laser" then
				startNoteData.noteType = "LongNoteStart"
			else
				startNoteData.noteType = "LaserNoteStart"
			end

			local endTimePoint = ld:getTimePoint(endMeasureTime)

			local endNoteData = ncdk.NoteData:new(endTimePoint)
			endNoteData.sounds = {}

			if _noteData.input ~= "laser" then
				endNoteData.noteType = "LongNoteEnd"
			else
				endNoteData.noteType = "LaserNoteEnd"
			end

			endNoteData.startNoteData = startNoteData
			startNoteData.endNoteData = endNoteData

			ld:addNoteData(endNoteData, inputType, inputIndex)

			lastTimePoint = endTimePoint
		end

		self.noteCount = self.noteCount + 1

		if not self.minTimePoint or lastTimePoint < self.minTimePoint then
			self.minTimePoint = lastTimePoint
		end

		if not self.maxTimePoint or lastTimePoint > self.maxTimePoint then
			self.maxTimePoint = lastTimePoint
		end
	end
end

NoteChartImporter.processMeasureLines = function(self)
	for measureIndex = 0, self.measureCount do
		local measureTime = ncdk.Fraction:new(measureIndex)
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime)

		local startNoteData = ncdk.NoteData:new(timePoint)
		startNoteData.noteType = "LineNoteStart"
		self.foregroundLayerData:addNoteData(startNoteData, "measure", 1)

		local endNoteData = ncdk.NoteData:new(timePoint)
		endNoteData.noteType = "LineNoteEnd"
		self.foregroundLayerData:addNoteData(endNoteData, "measure", 1)

		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData
	end
end

return NoteChartImporter
