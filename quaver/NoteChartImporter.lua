local tinyyaml = require("tinyyaml")
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
	self.foregroundLayerData = self.noteChart.layerDataSequence:requireLayerData(1)
	
	self.foregroundLayerData.timeData:setMode(ncdk.TimeData.Modes.Absolute)
	
	self.noteChartString = noteChartString
	self:process()
	
	self.noteChart.inputMode:setInputCount("key", tonumber(self.qua.Mode:sub(-1, -1)))
	self.noteChart.type = "quaver"
	
	self.noteChart:compute()
end

NoteChartImporter.process = function(self)
	self.metaData = {}
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}
	
	self.noteCount = 0
	
	self.qua = tinyyaml.parse(self.noteChartString)
	
	self:processMetaData()
	
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
	
	self.totalLength = self.maxTime - self.minTime
	self.noteChart:hashSet("totalLength", self.totalLength)
	self.noteChart:hashSet("noteCount", #HitObjects)
	
	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)
	
	self.foregroundLayerData:updateZeroTimePoint()
	
	self:updatePrimaryBPM()
	self.noteChart:hashSet("primaryBPM", self.primaryBPM)
	
	self:processMeasureLines()
	
	self.audioFileName = self.qua.AudioFile
	self:processAudio()
	
	self:processVelocityData()
	
	for _, noteParser in ipairs(self.noteDataImporters) do
		self.foregroundLayerData:addNoteData(noteParser:getNoteData())
	end
end

NoteChartImporter.processTimingDataImporters = osuNoteChartImporter.processTimingDataImporters
NoteChartImporter.updatePrimaryBPM = osuNoteChartImporter.updatePrimaryBPM
NoteChartImporter.processAudio = osuNoteChartImporter.processAudio
NoteChartImporter.processVelocityData = osuNoteChartImporter.processVelocityData
NoteChartImporter.processMeasureLines = osuNoteChartImporter.processMeasureLines

NoteChartImporter.processMetaData = function(self)
	self.noteChart:hashSet("AudioFile", self.qua.AudioFile)
	self.noteChart:hashSet("SongPreviewTime", self.qua.SongPreviewTime)
	self.noteChart:hashSet("BackgroundFile", self.qua.BackgroundFile)
	self.noteChart:hashSet("MapId", self.qua.MapId)
	self.noteChart:hashSet("MapSetId", self.qua.MapSetId)
	self.noteChart:hashSet("Mode", self.qua.Mode)
	self.noteChart:hashSet("Title", self.qua.Title)
	self.noteChart:hashSet("Artist", self.qua.Artist)
	self.noteChart:hashSet("Source", self.qua.Source)
	self.noteChart:hashSet("Tags", self.qua.Tags)
	self.noteChart:hashSet("Creator", self.qua.Creator)
	self.noteChart:hashSet("DifficultyName", self.qua.DifficultyName)
	self.noteChart:hashSet("Description", self.qua.Description)
end

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
