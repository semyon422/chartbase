local class = require("class")
local NoteDataExporter = require("osu.NoteDataExporter")
local TimingDataExporter = require("osu.TimingDataExporter")
local mappings = require("osu.exportKeyMappings")

---@class osu.NoteChartExporter
---@operator call: osu.NoteChartExporter
local NoteChartExporter = class()

---@return string
function NoteChartExporter:export()
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

function NoteChartExporter:loadNotes()
	local events = self.events
	local hitObjects = self.hitObjects

	local _noteDatas = {}
	local samples = {}

	for _, layerData in self.noteChart:getLayerDataIterator() do
		for inputType, r in pairs(layerData.noteDatas) do
			for inputIndex, noteDatas in pairs(r) do
				for _, noteData in ipairs(noteDatas) do
					noteData.inputType = inputType
					noteData.inputIndex = inputIndex
					if noteData.noteType == "ShortNote" or noteData.noteType == "LongNoteStart" then
						table.insert(_noteDatas, noteData)
					elseif noteData.noteType == "SoundNote" then
						if noteData.stream then
							self.audio_path = noteData.sounds[1][1]
						else
							table.insert(samples, noteData)
						end
					end
				end
			end
		end
	end

	table.sort(_noteDatas)
	table.sort(samples)

	local nde = NoteDataExporter()
	nde.mappings = self.mappings
	for _, noteData in ipairs(_noteDatas) do
		nde.noteData = noteData
		hitObjects[#hitObjects + 1] = nde:getHitObject()
	end

	for _, noteData in ipairs(samples) do
		nde.noteData = noteData
		events[#events + 1] = nde:getEventSample()
	end
end

function NoteChartExporter:addHeader()
	local lines = self.lines
	local chartmeta = self.chartmeta

	lines[#lines + 1] = "osu file format v14"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "[General]"

	local audio_path = chartmeta.audio_path
	if audio_path and audio_path ~= "" then
		lines[#lines + 1] = "AudioFilename: " .. audio_path
	else
		lines[#lines + 1] = "AudioFilename: virtual"
	end

	local name =  chartmeta.name
	if chartmeta.level and chartmeta.level > 0 then
		name = name .. " " .. chartmeta.level
	end

	lines[#lines + 1] = "AudioLeadIn: 0"
	lines[#lines + 1] = "PreviewTime: " .. math.floor((chartmeta.preview_time or 0) * 1000)
	lines[#lines + 1] = "Countdown: 0"
	lines[#lines + 1] = "SampleSet: Soft"
	lines[#lines + 1] = "StackLeniency: 0.7"
	lines[#lines + 1] = "Mode: 3"
	lines[#lines + 1] = "LetterboxInBreaks: 0"
	lines[#lines + 1] = ""
	lines[#lines + 1] = "[Metadata]"
	lines[#lines + 1] = "Title:" .. (chartmeta.title or "")
	lines[#lines + 1] = "TitleUnicode:" .. (chartmeta.title or "")
	lines[#lines + 1] = "Artist:" .. (chartmeta.artist or "")
	lines[#lines + 1] = "ArtistUnicode:" .. (chartmeta.artist or "")
	lines[#lines + 1] = "Creator:" .. (chartmeta.creator or "")
	lines[#lines + 1] = "Version:" .. (name or "")
	lines[#lines + 1] = "Source:" .. (chartmeta.source or "")
	lines[#lines + 1] = "Tags:" .. (chartmeta.tags or "")
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

function NoteChartExporter:addEvents()
	local lines = self.lines
	local events = self.events
	local chartmeta = self.chartmeta

	lines[#lines + 1] = "[Events]"

	lines[#lines + 1] = "//Background and Video events"
	local background_path = chartmeta.background_path
	if background_path and background_path ~= "" then
		lines[#lines + 1] = ("0,0,\"%s\",0,0"):format(background_path)
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

---@param a table
---@param b table
---@return boolean
local function sortTimingStates(a, b)
	return a.time < b.time
end

function NoteChartExporter:addTimingPoints()
	local timingStates = {}

	local layerData = self.noteChart:getLayerData(1)
	for tempoDataIndex = 1, layerData:getTempoDataCount() do
		local tde = TimingDataExporter()
		tde.tempoData = layerData:getTempoData(tempoDataIndex)

		local time = tde.tempoData.timePoint.absoluteTime
		timingStates[time] = timingStates[time] or {}
		timingStates[time].tempo = tde
	end
	for stopDataIndex = 1, layerData:getStopDataCount() do
		local tde = TimingDataExporter()
		tde.stopData = layerData:getStopData(stopDataIndex)

		local time = tde.stopData.leftTimePoint.absoluteTime
		timingStates[time] = timingStates[time] or {}
		timingStates[time].stop = tde
	end
	for velocityDataIndex = 1, layerData:getVelocityDataCount() do
		local tde = TimingDataExporter()
		tde.velocityData = layerData:getVelocityData(velocityDataIndex)

		local time = tde.velocityData.timePoint.absoluteTime
		timingStates[time] = timingStates[time] or {}
		timingStates[time].velocity = tde
	end
	for intervalDataIndex = 1, layerData:getIntervalDataCount() - 1 do
		local tde = TimingDataExporter()
		tde.intervalData = layerData:getIntervalData(intervalDataIndex)

		local time = tde.intervalData.timePoint.absoluteTime
		timingStates[time] = timingStates[time] or {}
		timingStates[time].interval = tde
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
		if timingState.velocity and (not timingState.tempo or timingState.velocity.velocityData.currentSpeed ~= 1) then
			lines[#lines + 1] = timingState.velocity:getVelocity()
		end
		if timingState.interval then
			lines[#lines + 1] = timingState.interval:getInterval()
		end
	end

	lines[#lines + 1] = ""
end

function NoteChartExporter:addHitObjects()
	local lines = self.lines
	local hitObjects = self.hitObjects

	lines[#lines + 1] = "[HitObjects]"
	for i = 1, #hitObjects do
		lines[#lines + 1] = hitObjects[i]
	end
end

return NoteChartExporter
