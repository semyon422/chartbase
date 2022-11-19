local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local Osu = require("osu.Osu")
local NoteDataExporter = require("osu.NoteDataExporter")
local TimingDataExporter = require("osu.TimingDataExporter")
local mappings = require("osu.exportKeyMappings")

local NoteChartExporter = {}

local NoteChartExporter_metatable = {}
NoteChartExporter_metatable.__index = NoteChartExporter

NoteChartExporter.new = function(self)
	local noteChartExporter = {}

	noteChartExporter.metaData = {}

	setmetatable(noteChartExporter, NoteChartExporter_metatable)

	return noteChartExporter
end

NoteChartExporter.export = function(self)
	local inputMode = self.noteChart.inputMode
	self.mappings = mappings[tostring(inputMode)]
	if not self.mappings then
		local keymode = inputMode.key
		self.mappings = {
			keymode = keymode or 1,
			key = {}
		}
	end

	self.events = {}
	self.hitObjects = {}
	self:loadNotes()

	self.lines = {}

	self:addHeader()
	self:addEvents()
	self:addTimingPoints()
	self:addHitObjects()

	return table.concat(self.lines, "\n")
end

NoteChartExporter.loadNotes = function(self)
	local events = self.events
	local hitObjects = self.hitObjects

	for _, layerData in self.noteChart:getLayerDataIterator() do
		for noteDataIndex = 1, layerData:getNoteDataCount() do
			local noteData = layerData:getNoteData(noteDataIndex)
			if noteData.noteType == "ShortNote" or noteData.noteType == "LongNoteStart" then
				local nde = NoteDataExporter:new()
				nde.mappings = self.mappings
				nde.noteData = noteData
				hitObjects[#hitObjects + 1] = nde:getHitObject()
			elseif noteData.noteType == "SoundNote" then
				if noteData.stream then
					self.audioPath = noteData.sounds[1][1]
				else
					local nde = NoteDataExporter:new()
					nde.noteData = noteData
					events[#events + 1] = nde:getEventSample()
				end
			end
		end
	end
end

NoteChartExporter.addHeader = function(self)
	local lines = self.lines
	local noteChartDataEntry = self.noteChartDataEntry

	lines[#lines + 1] = "osu file format v14"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "[General]"

	local audioPath = noteChartDataEntry.audioPath
	if audioPath ~= "" then
		lines[#lines + 1] = "AudioFilename: " .. audioPath
	else
		lines[#lines + 1] = "AudioFilename: virtual"
	end

	lines[#lines + 1] = "AudioLeadIn: 0"
	lines[#lines + 1] = "PreviewTime: " .. noteChartDataEntry.previewTime * 1000
	lines[#lines + 1] = "Countdown: 0"
	lines[#lines + 1] = "SampleSet: Soft"
	lines[#lines + 1] = "StackLeniency: 0.7"
	lines[#lines + 1] = "Mode: 3"
	lines[#lines + 1] = "LetterboxInBreaks: 0"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "[Metadata]"
	lines[#lines + 1] = "Title:" .. noteChartDataEntry.title
	lines[#lines + 1] = "TitleUnicode:" .. noteChartDataEntry.title
	lines[#lines + 1] = "Artist:" .. noteChartDataEntry.artist
	lines[#lines + 1] = "ArtistUnicode:" .. noteChartDataEntry.artist
	lines[#lines + 1] = "Creator:" .. noteChartDataEntry.creator
	lines[#lines + 1] = "Version:" .. noteChartDataEntry.name
	lines[#lines + 1] = "Source:" .. noteChartDataEntry.source
	lines[#lines + 1] = "Tags:" .. noteChartDataEntry.tags
	lines[#lines + 1] = "BeatmapID:0"
	lines[#lines + 1] = "BeatmapSetID:-1"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "[Difficulty]"
	lines[#lines + 1] = "HPDrainRate:5"

	lines[#lines + 1] = "CircleSize:" .. self.mappings.keymode

	lines[#lines + 1] = "OverallDifficulty:5"
	lines[#lines + 1] = "ApproachRate:5"
	lines[#lines + 1] = "SliderMultiplier:1.4"
	lines[#lines + 1] = "SliderTickRate:1"
	lines[#lines + 1] = ""
end

NoteChartExporter.addEvents = function(self)
	local lines = self.lines
	local events = self.events
	local noteChartDataEntry = self.noteChartDataEntry

	lines[#lines + 1] = "[Events]"

	lines[#lines + 1] = "//Background and Video events"
	local stagePath = noteChartDataEntry.stagePath
	if stagePath ~= "" then
		lines[#lines + 1] = ("0,0,\"%s\",0,0"):format(stagePath)
	end

	lines[#lines + 1] = "//Break Periods"
	lines[#lines + 1] = "//Storyboard Layer 0 (Background)"
	lines[#lines + 1] = "//Storyboard Layer 1 (Fail)"
	lines[#lines + 1] = "//Storyboard Layer 2 (Pass)"
	lines[#lines + 1] = "//Storyboard Layer 3 (Foreground)"

	lines[#lines + 1] = "//Storyboard Sound Samples"
	for i = 1, #events do
		lines[#lines + 1] = events[i]
	end

	lines[#lines + 1] = ""
end

local sortTimingStates = function(a, b)
	return a.time < b.time
end
NoteChartExporter.addTimingPoints = function(self)
	local timingStates = {}

	local layerData = self.noteChart:getLayerData(1)
	for tempoDataIndex = 1, layerData:getTempoDataCount() do
		local tde = TimingDataExporter:new()
		tde.tempoData = layerData:getTempoData(tempoDataIndex)

		local time = tde.tempoData.timePoint.absoluteTime
		timingStates[time] = timingStates[time] or {}
		timingStates[time].tempo = tde
	end
	for stopDataIndex = 1, layerData:getStopDataCount() do
		local tde = TimingDataExporter:new()
		tde.stopData = layerData:getStopData(stopDataIndex)

		local time = tde.stopData.leftTimePoint.absoluteTime
		timingStates[time] = timingStates[time] or {}
		timingStates[time].stop = tde
	end

	for velocityDataIndex = 1, layerData:getVelocityDataCount() do
		local tde = TimingDataExporter:new()
		tde.velocityData = layerData:getVelocityData(velocityDataIndex)
		if tde.velocityData.sv then
			local time = tde.velocityData.timePoint.absoluteTime
			timingStates[time] = timingStates[time] or {}
			timingStates[time].velocity = tde
		end
	end

	local timingStatesList = {}
	for time, timingState in pairs(timingStates) do
		timingState.time = time
		timingStatesList[#timingStatesList + 1] = timingState
	end
	table.sort(timingStatesList, sortTimingStates)

	local lines = self.lines

	lines[#lines + 1] = "[TimingPoints]"

	for i = 1, #timingStatesList do
		local timingState = timingStatesList[i]
		if timingState.stop then
			lines[#lines + 1] = timingState.stop:getStop()
		elseif timingState.tempo then
			lines[#lines + 1] = timingState.tempo:getTempo()
		end
		if timingState.velocity then
			lines[#lines + 1] = timingState.velocity:getVelocity()
		end
	end

	lines[#lines + 1] = ""
end

NoteChartExporter.addHitObjects = function(self)
	local lines = self.lines
	local hitObjects = self.hitObjects

	lines[#lines + 1] = "[HitObjects]"
	for i = 1, #hitObjects do
		lines[#lines + 1] = hitObjects[i]
	end
end

return NoteChartExporter
