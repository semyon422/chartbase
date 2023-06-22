local SPH = require("sph.SPH")
local NoteChart = require("ncdk.NoteChart")
local NoteData = require("ncdk.NoteData")
local Fraction = require("ncdk.Fraction")

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

	local sph = SPH:new()
	sph:import(self.content:gsub("\r[\r\n]?", "\n"))

	for _, interval in ipairs(sph.intervals) do
		layerData:insertIntervalData(interval.offset, interval.beats, interval.start)
	end

	local inputMap = sph.inputMap

	local minTimePoint, maxTimePoint
	local noteCount = 0
	local longNotes = {}
	for _, line in ipairs(sph.lines) do
		local intervalData = layerData:getIntervalData(line.intervalIndex)
		local timePoint = layerData:getTimePoint(intervalData, line.time, line.visualSide)

		local hasNote = false
		for i, note in ipairs(line.notes) do
			local noteData
			if note ~= "0" then
				noteData = NoteData:new(timePoint)
				local inputType, inputIndex = inputMap[i][1], inputMap[i][2]

				if note == "1" then
					noteData.noteType = "ShortNote"
					noteCount = noteCount + 1
					layerData:addNoteData(noteData, inputType, inputIndex)
				elseif note == "2" then
					noteData.noteType = "ShortNote"
					noteCount = noteCount + 1
					longNotes[i] = noteData
					layerData:addNoteData(noteData, inputType, inputIndex)
				elseif note == "3" and longNotes[i] then
					noteData.noteType = "LongNoteEnd"
					noteData.startNoteData = longNotes[i]
					longNotes[i].endNoteData = noteData
					longNotes[i].noteType = "LongNoteStart"
					longNotes[i] = nil
					layerData:addNoteData(noteData, inputType, inputIndex)
				elseif note == "4" then
					noteData.noteType = "SoundNote"
					layerData:addNoteData(noteData, inputType, inputIndex)
				end
				hasNote = true
			end
		end
		if line.velocity then
			layerData:insertVelocityData(timePoint, line.velocity)
		end
		if line.expand and line.expand ~= 0 then
			layerData:insertExpandData(timePoint, line.expand)
		end
		if line.measure then
			layerData:insertMeasureData(timePoint, line.measure)
		end

		if hasNote then
			if not minTimePoint or timePoint < minTimePoint then
				minTimePoint = timePoint
			end
			if not maxTimePoint or timePoint > maxTimePoint then
				maxTimePoint = timePoint
			end
		end
	end

	local backgroundLayerData = noteChart:getLayerData(2)
	backgroundLayerData:setTimeMode("absolute")
	local timePoint = backgroundLayerData:getTimePoint(0)

	local noteData = NoteData:new(timePoint)
	noteData.sounds = {{sph.metadata.audio, 1}}
	noteData.stream = true
	self.noteChart:addResource("sound", sph.metadata.audio, {sph.metadata.audio})

	noteData.noteType = "SoundNote"
	backgroundLayerData:addNoteData(noteData, "auto", 0)

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
