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
		local timePoint = self.backgroundLayerData:getTimePoint(startTime, -1)

		local noteData = ncdk.NoteData:new(timePoint)
		noteData.inputType = "auto"
		noteData.inputIndex = 0
		noteData.sounds = {{audioFileName, 1}}
		self.noteChart:addResource("sound", audioFileName, {audioFileName})

		noteData.noteType = "SoundNote"
		self.backgroundLayerData:addNoteData(noteData)
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
		local startTimePoint = ld:getTimePoint(startMeasureTime, -1)

		local startNoteData = ncdk.NoteData:new(startTimePoint)
		startNoteData.inputType = _noteData.input
		startNoteData.inputIndex = _noteData.lane
		if startNoteData.inputType == "fx" then
			startNoteData.inputIndex = _noteData.lane - 4
		end

		if _noteData.input == "laser" then
			if _noteData.lane == 1 then
				if _noteData.posStart < _noteData.posEnd then
					startNoteData.inputType = "laserright"
					startNoteData.inputIndex = 1
				elseif _noteData.posStart > _noteData.posEnd then
					startNoteData.inputType = "laserleft"
					startNoteData.inputIndex = 1
				end
			elseif _noteData.lane == 2 then
				if _noteData.posStart < _noteData.posEnd then
					startNoteData.inputType = "laserright"
					startNoteData.inputIndex = 2
				elseif _noteData.posStart > _noteData.posEnd then
					startNoteData.inputType = "laserleft"
					startNoteData.inputIndex = 2
				end
			end
		end

		startNoteData.sounds = {}

		ld:addNoteData(startNoteData)

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

			local endTimePoint = ld:getTimePoint(endMeasureTime, -1)

			local endNoteData = ncdk.NoteData:new(endTimePoint)
			endNoteData.inputType = startNoteData.inputType
			endNoteData.inputIndex = startNoteData.inputIndex
			endNoteData.sounds = {}

			if _noteData.input ~= "laser" then
				endNoteData.noteType = "LongNoteEnd"
			else
				endNoteData.noteType = "LaserNoteEnd"
			end

			endNoteData.startNoteData = startNoteData
			startNoteData.endNoteData = endNoteData

			ld:addNoteData(endNoteData)

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
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)

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
