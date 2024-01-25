local tinyyaml = require("tinyyaml")
local NoteChart = require("ncdk.NoteChart")
local Chartmeta = require("notechart.Chartmeta")
local osuNoteChartImporter = require("osu.NoteChartImporter")

local class = require("class")
local NoteDataImporter = require("quaver.NoteDataImporter")
local TimingDataImporter = require("quaver.TimingDataImporter")

---@class quaver.NoteChartImporter
---@operator call: quaver.NoteChartImporter
local NoteChartImporter = class()

function NoteChartImporter:import()
	self.noteChart = NoteChart()
	local noteChart = self.noteChart

	if not self.qua then
		self.qua = tinyyaml.parse(self.content:gsub("\r\n", "\n"))
	end

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("absolute")

	self:process()

	noteChart.inputMode.key = tonumber(self.qua.Mode:sub(-1, -1))
	noteChart.type = "quaver"

	noteChart:compute()

	local qua = self.qua
	noteChart.chartmeta = Chartmeta({
		format = "qua",
		title = tostring(qua["Title"]),  -- yaml can be parsed as number
		artist = tostring(qua["Artist"]),
		source = tostring(qua["Source"]),
		tags = tostring(qua["Tags"]),
		name = tostring(qua["DifficultyName"]),
		creator = tostring(qua["Creator"]),
		audio_path = tostring(qua["AudioFile"]),
		background_path = tostring(qua["BackgroundFile"]),
		preview_time = (qua["SongPreviewTime"] or 0) / 1000,
		notes_count = self.notes_count,
		duration = self.totalLength / 1000,
		tempo = self.primaryBPM,
		tempo_avg = self.primaryBPM,
		inputmode = tostring(noteChart.inputMode),
		start_time = self.minTime / 1000,
	})

	self.noteCharts = {noteChart}
end

function NoteChartImporter:process()
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}

	self.notes_count = 0

	local TimingPoints = self.qua.TimingPoints
	for i = 1, #TimingPoints do
		self:addTimingPointParser(TimingPoints[i])
	end

	local SliderVelocities = self.qua.SliderVelocities
	for i = 1, #SliderVelocities do
		self:addTimingPointParser(SliderVelocities[i])
	end

	local HitObjects = self.qua.HitObjects
	for i = 1, #HitObjects do
		self:addNoteParser(HitObjects[i])
	end

	self:updateLength()
	self.notes_count = #HitObjects

	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)

	self:updatePrimaryBPM()
	self.foregroundLayerData:setPrimaryTempo(self.primaryBPM)

	self:processMeasureLines()

	self.audioFileName = self.qua.AudioFile
	self:processAudio()

	self:processTimingPoints()

	for _, noteParser in ipairs(self.noteDataImporters) do
		self:addNoteDatas(noteParser:getNoteData())
	end
end

NoteChartImporter.addNoteDatas = osuNoteChartImporter.addNoteDatas
NoteChartImporter.updateLength = osuNoteChartImporter.updateLength
NoteChartImporter.processTimingDataImporters = osuNoteChartImporter.processTimingDataImporters
NoteChartImporter.updatePrimaryBPM = osuNoteChartImporter.updatePrimaryBPM
NoteChartImporter.processAudio = osuNoteChartImporter.processAudio
NoteChartImporter.processTimingPoints = osuNoteChartImporter.processTimingPoints
NoteChartImporter.processMeasureLines = osuNoteChartImporter.processMeasureLines

---@param timingPoint table
function NoteChartImporter:addTimingPointParser(timingPoint)
	local timingDataImporter = TimingDataImporter()
	timingDataImporter.timingPoint = timingPoint
	timingDataImporter.noteChartImporter = self
	timingDataImporter:init()

	table.insert(self.tempTimingDataImporters, timingDataImporter)
end

---@param hitObject table
function NoteChartImporter:addNoteParser(hitObject)
	local noteDataImporter = NoteDataImporter()
	noteDataImporter.hitObject = hitObject
	noteDataImporter.noteChartImporter = self
	noteDataImporter.noteChart = self.noteChart
	noteDataImporter:init()

	table.insert(self.noteDataImporters, noteDataImporter)
end

return NoteChartImporter
