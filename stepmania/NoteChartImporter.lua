local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local SM = require("stepmania.SM")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self)
	local noteCharts = {}

	if not self.sm then
		self.sm = SM:new()
		self.sm:import(self.content:gsub("\r[\r\n]?", "\n"))
	end

	local i0, i1 = 1, #self.sm.charts
	if self.index then
		i0, i1 = self.index, self.index
	end

	for i = i0, i1 do
		local importer = NoteChartImporter:new()
		importer.sm = self.sm
		importer.chartIndex = i
		importer.chart = self.sm.charts[i]
		noteCharts[#noteCharts + 1] = importer:importSingle()
	end

	self.noteCharts = noteCharts
end

NoteChartImporter.importSingle = function(self)
	self.noteChart = NoteChart:new()
	local noteChart = self.noteChart

	self.foregroundLayerData = noteChart.layerDataSequence:requireLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")

	self.backgroundLayerData = noteChart.layerDataSequence:requireLayerData(2)
	self.backgroundLayerData.invisible = true
	self.backgroundLayerData:setTimeMode("absolute")

	noteChart.inputMode.key = self.chart.mode
	self:processTempo()
	self:processNotes()
	self:processAudio()
	self:processMeasureLines()

	noteChart.type = "sm"
	noteChart:compute()

	self:updateLength()

	noteChart.index = self.chartIndex
	noteChart.metaData = MetaData(noteChart, self)

	return noteChart
end

NoteChartImporter.updateLength = function(self)
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

NoteChartImporter.processTempo = function(self)
	for _, bpm in ipairs(self.sm.bpm) do
		self:setTempo(bpm.beat, bpm.tempo)
	end
end

NoteChartImporter.setTempo = function(self, beat, tempo)
	local measureTime = ncdk.Fraction:new(beat / 4, 1000, true)
	self.currentTempoData = ncdk.TempoData:new(
		measureTime,
		tempo
	)
	self.foregroundLayerData:addTempoData(self.currentTempoData)

	local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
	self.currentVelocityData = ncdk.VelocityData:new(timePoint)
	self.currentVelocityData.currentSpeed = tempo / self.sm.primaryTempo
	self.foregroundLayerData:addVelocityData(self.currentVelocityData)
end


NoteChartImporter.processNotes = function(self)
	self.noteCount = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil

	local longNotes = {}
	for _, note in ipairs(self.chart.notes) do
		local measureTime = ncdk.Fraction:new(note.offset, self.chart.linesPerMeasure[note.measure]) + note.measure
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)

		local noteData = ncdk.NoteData:new(timePoint)
		noteData.inputType = "key"
		noteData.inputIndex = note.inputIndex

		noteData.sounds = {}
		noteData.images = {}

		if note.noteType == "1" then
			noteData.noteType = "ShortNote"
			self.noteCount = self.noteCount + 1
		elseif note.noteType == "M" or note.noteType == "F" then
			noteData.noteType = "SoundNote"
		elseif note.noteType == "2" or note.noteType == "4" then
			noteData.noteType = "ShortNote"
			longNotes[noteData.inputIndex] = noteData
			self.noteCount = self.noteCount + 1
		elseif note.noteType == "3" then
			noteData.noteType = "LongNoteEnd"
			noteData.startNoteData = longNotes[noteData.inputIndex]
			longNotes[noteData.inputIndex].endNoteData = noteData
			longNotes[noteData.inputIndex].noteType = "LongNoteStart"
			longNotes[noteData.inputIndex] = nil
		end

		self.foregroundLayerData:addNoteData(noteData)

		if not self.minTimePoint or timePoint < self.minTimePoint then
			self.minTimePoint = timePoint
		end

		if not self.maxTimePoint or timePoint > self.maxTimePoint then
			self.maxTimePoint = timePoint
		end
	end
end

NoteChartImporter.processAudio = function(self)
	local startTime = tonumber(self.sm.header["OFFSET"]) or 0
	local timePoint = self.backgroundLayerData:getTimePoint(startTime, -1)

	local noteData = ncdk.NoteData:new(timePoint)
	noteData.inputType = "auto"
	noteData.inputIndex = 0
	noteData.sounds = {{self.sm.header["MUSIC"], 1}}
	noteData.stream = true
	self.noteChart:addResource("sound", self.sm.header["MUSIC"], {self.sm.header["MUSIC"]})

	noteData.noteType = "SoundNote"
	self.backgroundLayerData:addNoteData(noteData)
end

NoteChartImporter.processMeasureLines = function(self)
	for measureIndex = 0, self.chart.measure do
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
