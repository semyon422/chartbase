local SPH = require("sph.SPH")
local NoteChart = require("ncdk.NoteChart")
local IntervalTime = require("ncdk.IntervalTime")
local NoteData = require("ncdk.NoteData")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self)
	self.noteChart = NoteChart:new()
	local noteChart = self.noteChart

	local layerData = noteChart:getLayerData(1)
	layerData:setTimeMode("interval")
	layerData:setSignatureMode("short")
	self.foregroundLayerData = layerData

	local sph = SPH:new()
	sph:import(self.content:gsub("\r[\r\n]?", "\n"))

	for _, interval in ipairs(sph.intervals) do
		layerData:insertIntervalData(interval.offset, interval.intervals)
	end

	local minTimePoint, maxTimePoint
	local noteCount = 0
	for _, line in ipairs(sph.lines) do
		local intervalData = layerData:getIntervalData(line.intervalIndex)
		local timePoint = layerData:getTimePoint(IntervalTime:new(intervalData, line.time))
		for i, note in ipairs(line.notes) do
			if note ~= "0" then
				local noteData = NoteData:new(timePoint, "key", i)
				noteData.noteType = "ShortNote"
				layerData:addNoteData(noteData)
				noteCount = noteCount + 1
			end
		end

		if not minTimePoint or timePoint < minTimePoint then
			minTimePoint = timePoint
		end
		if not maxTimePoint or timePoint > maxTimePoint then
			maxTimePoint = timePoint
		end
	end

	noteChart.type = "bms"
	noteChart:compute()

	local totalLength, minTime, maxTime = 0, 0, 0
	if maxTimePoint and minTimePoint then
		totalLength = maxTimePoint.absoluteTime - minTimePoint.absoluteTime
		minTime = minTimePoint.absoluteTime
		maxTime = maxTimePoint.absoluteTime
	end

	noteChart.index = 1
	noteChart.metaData = {
		hash = "",
		index = 1,
		format = "sph",
		title = sph.metadata.title,
		artist = sph.metadata.artist,
		source = sph.metadata.source,
		tags = sph.metadata.tags,
		name = sph.metadata.name,
		creator = sph.metadata.creator,
		level = sph.metadata.level,
		audioPath = sph.metadata.audio,
		stagePath = sph.metadata.background,
		previewTime = sph.metadata.preview,
		noteCount = noteCount,
		length = totalLength,
		bpm = sph.metadata.bpm,
		inputMode = sph.metadata.input,
		minTime = minTime,
		maxTime = maxTime,
	}

	noteChart.inputMode:set(sph.metadata.input)

	self.noteCharts = {noteChart}
end

return NoteChartImporter
