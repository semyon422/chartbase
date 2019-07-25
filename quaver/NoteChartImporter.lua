local tinyyaml = require("tinyyaml")
local NoteChart = require("ncdk.NoteChart")
local osuNoteChartImporter = require("osu.NoteChartImporter")

local ncdk = require("ncdk")
local NoteDataImporter = require("quaver.NoteDataImporter")
local TimingDataImporter = require("quaver.TimingDataImporter")

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
	self.noteChart = NoteChart:new()
	self.noteChart.importer = self
	
	if not self.qua then
		self.qua = tinyyaml.parse(noteChartString)
	end
	
	self.foregroundLayerData = self.noteChart.layerDataSequence:requireLayerData(1)
	self.foregroundLayerData:setTimeMode("absolute")
	
	self:process()
	
	self.noteChart.inputMode:setInputCount("key", tonumber(self.qua.Mode:sub(-1, -1)))
	self.noteChart.type = "quaver"
	
	self.noteChart:compute()
	
	return self.noteChart
end

NoteChartImporter.process = function(self)
	self.metaData = {}
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}
	
	self.noteCount = 0
	
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
	self.noteChart:hashSet("noteCount", #HitObjects)
	
	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)
	
	self.foregroundLayerData:updateZeroTimePoint()
	
	self:updatePrimaryBPM()
	
	self:processMeasureLines()
	
	self.audioFileName = self.qua.AudioFile
	self:processAudio()
	
	self:processVelocityData()
	
	for _, noteParser in ipairs(self.noteDataImporters) do
		self.foregroundLayerData:addNoteData(noteParser:getNoteData())
	end
end

NoteChartImporter.updateLength = osuNoteChartImporter.updateLength
NoteChartImporter.processTimingDataImporters = osuNoteChartImporter.processTimingDataImporters
NoteChartImporter.updatePrimaryBPM = osuNoteChartImporter.updatePrimaryBPM
NoteChartImporter.processAudio = osuNoteChartImporter.processAudio
NoteChartImporter.processVelocityData = osuNoteChartImporter.processVelocityData
NoteChartImporter.processMeasureLines = osuNoteChartImporter.processMeasureLines

NoteChartImporter.addTimingPointParser = function(self, timingPoint)
	local timingDataImporter = TimingDataImporter:new()
	timingDataImporter.timingPoint = timingPoint
	timingDataImporter.noteChartImporter = self
	timingDataImporter:init()
	
	table.insert(self.tempTimingDataImporters, timingDataImporter)
end

NoteChartImporter.addNoteParser = function(self, hitObject)
	local noteDataImporter = NoteDataImporter:new()
	noteDataImporter.hitObject = hitObject
	noteDataImporter.noteChartImporter = self
	noteDataImporter.noteChart = self.noteChart
	noteDataImporter:init()
	
	table.insert(self.noteDataImporters, noteDataImporter)
end

return NoteChartImporter
