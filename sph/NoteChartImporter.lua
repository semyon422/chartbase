local class = require("class")
local Sph = require("sph.Sph")
local NoteChart = require("ncdk.NoteChart")
local NoteData = require("ncdk.NoteData")
local InputMode = require("ncdk.InputMode")

---@class sph.NoteChartImporter
---@operator call: sph.NoteChartImporter
local NoteChartImporter = class()

function NoteChartImporter:new()
	self.noteChart = NoteChart()
	self.sph = Sph()
	self.noteCount = 0
	self.longNotes = {}
end

function NoteChartImporter:import()
	local sph = self.sph
	local content = self.content:gsub("\r[\r\n]?", "\n")
	sph:decode(content)

	local noteChart = self.noteChart

	noteChart.inputMode = InputMode(sph.metadata.input)
	self.inputMap = noteChart.inputMode:getInputMap()

	local layerData = noteChart:getLayerData(1)
	layerData:setTimeMode("interval")
	self.layerData = layerData

	for _, interval in ipairs(sph.sphLines.intervals) do
		layerData:insertIntervalData(interval.offset, interval.beats, interval.start)
	end

	for _, line in ipairs(sph.sphLines.lines) do
		self:processLine(line)
	end

	self:addAudio()

	noteChart.type = "bms"
	noteChart:compute()

	self:setMetadata()

	self.noteCharts = {noteChart}
end

---@param line table
function NoteChartImporter:processLine(line)
	local layerData = self.layerData
	local inputMap = self.inputMap
	local longNotes = self.longNotes
	local sounds = self.sph.sounds

	local intervalData = layerData:getIntervalData(line.intervalIndex)
	local timePoint = layerData:getTimePoint(intervalData, line.time, line.visualSide)

	timePoint.comment = line.comment

	local line_sounds = line.sounds or {}
	local line_volume = line.volume or {}
	for i, note in ipairs(line.notes) do
		local noteData = NoteData(timePoint)

		local sound = sounds[line_sounds[i]]
		if sound then
			noteData.sounds = {{sound, line_volume[i] or 1}}
			self.noteChart:addResource("sound", sound, {sound})
		end

		local col = note.column
		local inputType, inputIndex = unpack(inputMap[col])

		local t = note.type
		if t == "1" then
			noteData.noteType = "ShortNote"
			self.noteCount = self.noteCount + 1
		elseif t == "2" then
			noteData.noteType = "ShortNote"
			self.noteCount = self.noteCount + 1
			longNotes[col] = noteData
		elseif t == "3" and longNotes[col] then
			noteData.noteType = "LongNoteEnd"
			noteData.startNoteData = longNotes[col]
			longNotes[col].endNoteData = noteData
			longNotes[col].noteType = "LongNoteStart"
			longNotes[col] = nil
		elseif t == "4" then
			noteData.noteType = "SoundNote"
		else
			error("unsupported note type " .. t)
		end

		layerData:addNoteData(noteData, inputType, inputIndex)
	end

	for i = #line.notes + 1, #line_sounds do
		local sound = sounds[line_sounds[i]]
		if sound then
			local noteData = NoteData(timePoint)
			noteData.noteType = "SoundNote"
			noteData.sounds = {{sound, line_volume[i] or 1}}
			self.noteChart:addResource("sound", sound, {sound})
			layerData:addNoteData(noteData, "auto", i)
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

	if #line.notes > 0 then
		self:updateBoundaries(timePoint)
	end
end

---@param timePoint ncdk.TimePoint
function NoteChartImporter:updateBoundaries(timePoint)
	if not self.minTimePoint or timePoint < self.minTimePoint then
		self.minTimePoint = timePoint
	end
	if not self.maxTimePoint or timePoint > self.maxTimePoint then
		self.maxTimePoint = timePoint
	end
end

function NoteChartImporter:addAudio()
	local sph = self.sph

	local layerData = self.noteChart:getLayerData(2)
	layerData:setTimeMode("absolute")

	local timePoint = layerData:getTimePoint(0)

	local noteData = NoteData(timePoint)
	noteData.sounds = {{sph.metadata.audio, 1}}
	noteData.stream = true
	self.noteChart:addResource("sound", sph.metadata.audio, {sph.metadata.audio})

	noteData.noteType = "SoundNote"
	layerData:addNoteData(noteData, "auto", 0)
end

function NoteChartImporter:setMetadata()
	local noteChart = self.noteChart
	local sph = self.sph

	local totalLength, minTime, maxTime = 0, 0, 0
	if self.maxTimePoint then
		totalLength = self.maxTimePoint.absoluteTime - self.minTimePoint.absoluteTime
		minTime = self.minTimePoint.absoluteTime
		maxTime = self.maxTimePoint.absoluteTime
	end

	noteChart.metaData = {
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
		noteCount = self.noteCount,
		length = totalLength,
		bpm = sph.metadata.bpm,
		inputMode = sph.metadata.input,
		minTime = minTime,
		maxTime = maxTime,
	}
end

return NoteChartImporter
