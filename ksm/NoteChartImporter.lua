local class = require("class")
local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local Chartmeta = require("notechart.Chartmeta")
local Ksh = require("ksm.Ksh")
local bmsNoteChartImporter = require("bms.NoteChartImporter")
local EncodingConverter = require("notechart.EncodingConverter")

---@class ksm.NoteChartImporter
---@operator call: ksm.NoteChartImporter
local NoteChartImporter = class()

NoteChartImporter.primaryTempo = 120
NoteChartImporter.measureCount = 0

local encodings = {
	"SHIFT-JIS",
	"ISO-8859-1",
	"CP932",
	"EUC-KR",
	"US-ASCII",
	"CP1252",
}

function NoteChartImporter:new()
	self.conv = EncodingConverter(encodings)
end

function NoteChartImporter:import()
	self.noteChart = NoteChart()
	local noteChart = self.noteChart

	if not self.ksh then
		self.ksh = Ksh()
		local content = self.content:gsub("\r\n", "\n")
		content = self.conv:convert(content)
		self.ksh:import(content)
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

	local ksh = self.ksh
	local options = ksh.options
	noteChart.chartmeta = Chartmeta({
		format = "ksh",
		title = options["title"],
		artist = options["artist"],
		name = options["difficulty"],
		creator = options["effect"],
		level = tonumber(options["level"]),
		audio_path = self.audioFileName,
		background_path = options["jacket"],
		preview_time = (options["plength"] or 0) / 1000,
		notes_count = self.notes_count,
		duration = self.totalLength,
		inputmode = tostring(noteChart.inputMode),
		start_time = self.minTime,
	})

	self.noteCharts = {noteChart}
end

NoteChartImporter.updateLength = bmsNoteChartImporter.updateLength

function NoteChartImporter:processAudio()
	local audioFileName = self.audioFileName

	if audioFileName then
		local startTime = -(tonumber(self.ksh.options.o) or 0) / 1000
		local timePoint = self.backgroundLayerData:getTimePoint(startTime)

		local noteData = ncdk.NoteData(timePoint)
		noteData.sounds = {{audioFileName, 1}}
		self.noteChart:addResource("sound", audioFileName, {audioFileName})

		noteData.noteType = "SoundNote"
		self.backgroundLayerData:addNoteData(noteData, "auto", 0)
	end
end

function NoteChartImporter:processData()
	self.notes_count = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil

	local ld = self.foregroundLayerData

	for _, tempoData in ipairs(self.ksh.tempos) do
		local measureTime = ncdk.Fraction(tempoData.lineOffset, tempoData.lineCount) + tempoData.measureOffset
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
		local startMeasureTime = ncdk.Fraction(_noteData.startLineOffset, _noteData.startLineCount) + _noteData.startMeasureOffset
		local startTimePoint = ld:getTimePoint(startMeasureTime)

		local startNoteData = ncdk.NoteData(startTimePoint)
		local inputType = _noteData.input
		local inputIndex = _noteData.lane
		if inputType == "fx" then
			inputIndex = _noteData.lane - 4
		end

		startNoteData.sounds = {}

		ld:addNoteData(startNoteData, inputType, inputIndex)

		local lastTimePoint = startTimePoint
		local endMeasureTime = ncdk.Fraction(_noteData.endLineOffset, _noteData.endLineCount) + _noteData.endMeasureOffset

		if startMeasureTime == endMeasureTime then
			startNoteData.noteType = "ShortNote"
		else
			if _noteData.input ~= "laser" then
				startNoteData.noteType = "LongNoteStart"
			else
				startNoteData.noteType = "LaserNoteStart"
			end

			local endTimePoint = ld:getTimePoint(endMeasureTime)

			local endNoteData = ncdk.NoteData(endTimePoint)
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

		self.notes_count = self.notes_count + 1

		if not self.minTimePoint or lastTimePoint < self.minTimePoint then
			self.minTimePoint = lastTimePoint
		end

		if not self.maxTimePoint or lastTimePoint > self.maxTimePoint then
			self.maxTimePoint = lastTimePoint
		end
	end
end

function NoteChartImporter:processMeasureLines()
	for measureIndex = 0, self.measureCount do
		local measureTime = ncdk.Fraction(measureIndex)
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime)

		local startNoteData = ncdk.NoteData(timePoint)
		startNoteData.noteType = "LineNoteStart"
		self.foregroundLayerData:addNoteData(startNoteData, "measure", 1)

		local endNoteData = ncdk.NoteData(timePoint)
		endNoteData.noteType = "LineNoteEnd"
		self.foregroundLayerData:addNoteData(endNoteData, "measure", 1)

		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData
	end
end

return NoteChartImporter
