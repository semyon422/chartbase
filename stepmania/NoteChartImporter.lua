local class = require("class")
local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local UnifiedMetaData = require("notechart.UnifiedMetaData")
local SM = require("stepmania.SM")
local EncodingConverter = require("notechart.EncodingConverter")

---@class stepmania.NoteChartImporter
---@operator call: stepmania.NoteChartImporter
local NoteChartImporter = class()

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
	local noteCharts = {}

	if not self.sm then
		self.sm = SM()
		local content = self.content:gsub("\r[\r\n]?", "\n")
		content = self.conv:convert(content)
		self.sm:import(content, self.path)
	end

	local i0, i1 = 1, #self.sm.charts
	if self.index then
		i0, i1 = self.index, self.index
	end

	for i = i0, i1 do
		local importer = NoteChartImporter()
		importer.sm = self.sm
		importer.chartIndex = i
		importer.chart = self.sm.charts[i]
		noteCharts[#noteCharts + 1] = importer:importSingle()
	end

	self.noteCharts = noteCharts
end

---@return ncdk.NoteChart
function NoteChartImporter:importSingle()
	self.noteChart = NoteChart()
	local noteChart = self.noteChart

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")
	self.foregroundLayerData:setSignatureMode("short")
	self.foregroundLayerData:setPrimaryTempo(120)

	self.backgroundLayerData = noteChart:getLayerData(2)
	self.backgroundLayerData.invisible = true
	self.backgroundLayerData:setTimeMode("absolute")
	self.backgroundLayerData:setPrimaryTempo(120)

	noteChart.inputMode.key = self.chart.mode
	self:processTempo()
	self:processNotes()
	self:processAudio()
	self:processMeasureLines()

	noteChart.type = "sm"
	noteChart:compute()

	self:updateLength()

	local sm = self.sm
	local header = sm.header
	local index = self.chartIndex
	local chart = self.chart

	noteChart.metaData = UnifiedMetaData({
		format = "sm",
		title = header["TITLE"],
		artist = header["ARTIST"],
		source = header["SUBTITLE"],
		name = chart.metaData[3],
		creator = header["CREDIT"],
		level = tonumber(chart.metaData[4]),
		audioPath = header["MUSIC"],
		stagePath = header["BACKGROUND"],
		previewTime = tonumber(header["SAMPLESTART"]) or 0,
		noteCount = self.noteCount,
		length = self.totalLength,
		bpm = sm.displayTempo or 0,
		inputMode = tostring(noteChart.inputMode),
		minTime = self.minTime,
		maxTime = self.maxTime,
	})

	return noteChart
end

function NoteChartImporter:updateLength()
	if self.maxTimePoint and self.minTimePoint then
		self.totalLength = self.maxTimePoint.absoluteTime - self.minTimePoint.absoluteTime
		self.minTime = self.minTimePoint.absoluteTime
		self.maxTime = self.maxTimePoint.absoluteTime
	else
		self.totalLength = 0
		self.minTime = 0
		self.maxTime = 0
	end
end

function NoteChartImporter:processTempo()
	local ld = self.foregroundLayerData
	for _, bpm in ipairs(self.sm.bpm) do
		local measureTime = ncdk.Fraction(bpm.beat / 4, 1000, true)
		ld:insertTempoData(measureTime, bpm.tempo)
	end
	for _, stop in ipairs(self.sm.stop) do
		local measureTime = ncdk.Fraction(stop.beat / 4, 1000, true)
		ld:insertStopData(measureTime, stop.duration, true)
	end
end

function NoteChartImporter:processNotes()
	self.noteCount = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil

	local longNotes = {}
	for _, note in ipairs(self.chart.notes) do
		local measureTime = ncdk.Fraction(note.offset, self.chart.linesPerMeasure[note.measure]) + note.measure
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime)

		local noteData = ncdk.NoteData(timePoint)

		noteData.sounds = {}
		noteData.images = {}

		if note.noteType == "1" then
			noteData.noteType = "ShortNote"
			self.noteCount = self.noteCount + 1
		elseif note.noteType == "M" or note.noteType == "F" then
			noteData.noteType = "SoundNote"
		elseif note.noteType == "2" or note.noteType == "4" then
			noteData.noteType = "ShortNote"
			longNotes[note.inputIndex] = noteData
			self.noteCount = self.noteCount + 1
		elseif note.noteType == "3" then
			noteData.noteType = "LongNoteEnd"
			noteData.startNoteData = longNotes[note.inputIndex]
			longNotes[note.inputIndex].endNoteData = noteData
			longNotes[note.inputIndex].noteType = "LongNoteStart"
			longNotes[note.inputIndex] = nil
		end

		self.foregroundLayerData:addNoteData(noteData, "key", note.inputIndex)

		if not self.minTimePoint or timePoint < self.minTimePoint then
			self.minTimePoint = timePoint
		end

		if not self.maxTimePoint or timePoint > self.maxTimePoint then
			self.maxTimePoint = timePoint
		end
	end
end

function NoteChartImporter:processAudio()
	local startTime = tonumber(self.sm.header["OFFSET"]) or 0
	local timePoint = self.backgroundLayerData:getTimePoint(startTime)

	local noteData = ncdk.NoteData(timePoint)
	noteData.sounds = {{self.sm.header["MUSIC"], 1}}
	noteData.stream = true
	noteData.streamOffset = startTime
	self.noteChart:addResource("sound", self.sm.header["MUSIC"], {self.sm.header["MUSIC"]})

	noteData.noteType = "SoundNote"
	self.backgroundLayerData:addNoteData(noteData, "auto", 0)
end

function NoteChartImporter:processMeasureLines()
	for measureIndex = 0, self.chart.measure do
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
