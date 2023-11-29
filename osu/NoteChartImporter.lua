local class = require("class")
local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local UnifiedMetaData = require("notechart.UnifiedMetaData")
local Osu = require("osu.Osu")
local NoteDataImporter = require("osu.NoteDataImporter")
local TimingDataImporter = require("osu.TimingDataImporter")

---@class osu.NoteChartImporter
---@operator call: osu.NoteChartImporter
local NoteChartImporter = class()

function NoteChartImporter:import()
	self.noteChart = NoteChart()
	local noteChart = self.noteChart

	if not self.osu then
		self.osu = Osu()
		local content = self.content:gsub("\r\n", "\n")
		self.osu:import(content)
	end

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("absolute")
	self.foregroundLayerData:setSignatureMode("long")

	self:process()

	local mode = self.osu.mode
	if mode == 0 then
		noteChart.inputMode.osu = 1
	elseif mode == 1 then
		noteChart.inputMode.key = 2
	elseif mode == 2 then
		noteChart.inputMode.fruits = 1
	elseif mode == 3 then
		noteChart.inputMode.key = math.floor(self.osu.keymode)
	end
	noteChart.type = "osu"
	noteChart:compute()

	local metadata = self.osu.metadata
	noteChart.metaData = UnifiedMetaData({
		format = "osu",
		title = metadata.Title,
		artist = metadata.Artist,
		source = metadata.Source,
		tags = metadata.Tags,
		name = metadata.Version,
		creator = metadata.Creator,
		audioPath = metadata.AudioFilename,
		stagePath = self.osu.background,
		previewTime = metadata.PreviewTime / 1000,
		noteCount = self.noteCount,
		length = self.totalLength / 1000,
		bpm = self.primaryBPM,
		inputMode = tostring(noteChart.inputMode),
		minTime = self.minTime / 1000,
		maxTime = self.maxTime / 1000,
		avgTempo = self.primaryBPM,
		minTempo = self.minTempo,
		maxTempo = self.maxTempo,
	})

	self.noteCharts = {noteChart}
end

---@param ... ncdk.NoteData?
function NoteChartImporter:addNoteDatas(...)
	for i = 1, select("#", ...) do
		local noteData = select(i, ...)
		if noteData then
			self.foregroundLayerData:addNoteData(noteData, noteData.inputType, noteData.inputIndex)
		end
	end
end

function NoteChartImporter:process()
	self.eventParsers = {}
	self.tempTimingDataImporters = {}
	self.timingDataImporters = {}
	self.noteDataImporters = {}

	self.noteCount = 0

	for _, event in ipairs(self.osu.events) do
		self:addNoteParser(event, true)
	end

	for _, tp in ipairs(self.osu.timingPoints) do
		self:addTimingPointParser(tp)
	end

	for _, note in ipairs(self.osu.hitObjects) do
		self:addNoteParser(note)
	end

	self:updateLength()

	self:processTimingDataImporters()
	table.sort(self.noteDataImporters, function(a, b) return a.startTime < b.startTime end)

	self:updatePrimaryBPM()

	self:processMeasureLines()

	self.audioFileName = self.osu.metadata["AudioFilename"]
	self:processAudio()
	self:processTimingPoints()

	for _, noteParser in ipairs(self.noteDataImporters) do
		self:addNoteDatas(noteParser:getNoteData())
	end
end

function NoteChartImporter:updateLength()
	self.minTime = self.minTime or 0
	self.maxTime = self.maxTime or 0
	self.totalLength = self.maxTime - self.minTime
end

---@param a table
---@param b table
---@return boolean
local function compareTdi(a, b)
	if a.startTime == b.startTime then
		return a.timingChange and a.timingChange ~= b.timingChange
	end
	return a.startTime < b.startTime
end

function NoteChartImporter:processTimingDataImporters()
	local redTimingData = {}
	local greenTimingData = {}

	for i = #self.tempTimingDataImporters, 1, -1 do
		local tdi = self.tempTimingDataImporters[i]
		if tdi.timingChange and not redTimingData[tdi.startTime] then
			redTimingData[tdi.startTime] = tdi
		elseif not tdi.timingChange and not greenTimingData[tdi.startTime] then
			greenTimingData[tdi.startTime] = tdi
		end
	end

	for _, timingDataImporter in pairs(redTimingData) do
		table.insert(self.timingDataImporters, timingDataImporter)
	end

	for _, timingDataImporter in pairs(greenTimingData) do
		table.insert(self.timingDataImporters, timingDataImporter)
	end

	table.sort(self.timingDataImporters, compareTdi)
end

function NoteChartImporter:updatePrimaryBPM()
	local lastTime = self.maxTime
	local currentBeatLength = 0
	local bpmDurations = {}

	local min_bl = math.huge
	local max_bl = -math.huge

	for i = #self.timingDataImporters, 1, -1 do
		local tdi = self.timingDataImporters[i]

		if tdi.timingChange then
			currentBeatLength = tdi.beatLength
			min_bl = math.min(min_bl, currentBeatLength)
			max_bl = math.max(max_bl, currentBeatLength)
		end

		if not (currentBeatLength == 0 or tdi.startTime > lastTime or (not tdi.timingChange and i > 1)) then
			bpmDurations[currentBeatLength] = bpmDurations[currentBeatLength] or 0
			bpmDurations[currentBeatLength] = bpmDurations[currentBeatLength] + (lastTime - (i == 1 and 0 or tdi.startTime))

			lastTime = tdi.startTime
		end
	end

	local longestDuration = 0
	local average = 0

	for beatLength, duration in pairs(bpmDurations) do
		if duration > longestDuration then
			longestDuration = duration
			average = beatLength
		end
	end

	if longestDuration == 0 then
		self.primaryBeatLength = 0
		self.primaryBPM = 0
		self.minTempo = 0
		self.maxTempo = 0
		return
	end

	self.primaryBeatLength = average
	self.primaryBPM = 60000 / average
	self.minTempo = 60000 / max_bl
	self.maxTempo = 60000 / min_bl
end

function NoteChartImporter:processAudio()
	local audioFileName = self.audioFileName

	if audioFileName and audioFileName ~= "virtual" then
		local timePoint = self.foregroundLayerData:getTimePoint(0)

		local noteData = ncdk.NoteData(timePoint)
		noteData.sounds = {{audioFileName, 1}}
		noteData.stream = true
		self.noteChart:addResource("sound", audioFileName, {audioFileName})

		noteData.noteType = "SoundNote"
		self.foregroundLayerData:addNoteData(noteData, "auto", 0)
	end
end

function NoteChartImporter:processTimingPoints()
	local ld = self.foregroundLayerData
	ld:setPrimaryTempo(120)
	-- ld:setPrimaryTempo(self.primaryBPM)

	local timingState = {}
	for i = 1, #self.timingDataImporters do
		local tdi = self.timingDataImporters[i]

		timingState[tdi.startTime] = timingState[tdi.startTime] or {}

		local data = timingState[tdi.startTime]
		if tdi.timingChange then
			data.beatLength = tdi.beatLength
		else
			data.velocity = tdi.velocity
		end
	end

	for offset, data in pairs(timingState) do
		local time = offset / 1000

		if data.velocity then
			ld:insertVelocityData(ld:getTimePoint(time), data.velocity)
		end
		if data.beatLength then
			ld:insertTempoData(time, 60000 / data.beatLength)
			if not data.velocity then
				ld:insertVelocityData(ld:getTimePoint(time), 1)
			end
		end
	end
end

---@param tp table
function NoteChartImporter:addTimingPointParser(tp)
	local timingDataImporter = TimingDataImporter(tp)
	timingDataImporter.noteChartImporter = self
	timingDataImporter:init()

	table.insert(self.tempTimingDataImporters, timingDataImporter)
end

---@param note table
---@param event boolean?
function NoteChartImporter:addNoteParser(note, event)
	local noteDataImporter = NoteDataImporter(note)
	noteDataImporter.noteChartImporter = self
	noteDataImporter.noteChart = self.noteChart
	noteDataImporter.mode = self.osu.mode
	if not event then
		noteDataImporter:init()
		self.noteCount = self.noteCount + 1
	else
		noteDataImporter:initEvent()
	end

	table.insert(self.noteDataImporters, noteDataImporter)
end

function NoteChartImporter:processMeasureLines()
	local offset
	local firstTdi
	for i = 1, #self.timingDataImporters do
		local tdi = self.timingDataImporters[i]
		if tdi.timingChange then
			firstTdi = tdi
			offset = firstTdi.startTime
			break
		end
	end
	if not firstTdi then
		return
	end

	if offset > 0 then
		while true do
			if offset - firstTdi.measureLength <= 0 then
				break
			else
				offset = offset - firstTdi.measureLength
			end
		end
	elseif offset < 0 then
		offset = offset + math.floor(-offset / firstTdi.measureLength) * firstTdi.measureLength
	end

	local lines = {}
	for i = 1, #self.timingDataImporters do
		local currentTdi = self.timingDataImporters[i]
		if currentTdi.timingChange then
			local nextTdi
			for j = i + 1, #self.timingDataImporters do
				if self.timingDataImporters[j].timingChange then
					nextTdi = self.timingDataImporters[j]
					break
				end
			end

			local nextLastTime = math.min(nextTdi and nextTdi.startTime - 1 or self.maxTime, self.maxTime)
			while true do
				if offset < nextLastTime then
					table.insert(lines, offset)
					offset = offset + math.max(1, currentTdi.measureLength)
				else
					offset = nextLastTime + 1
					break
				end
			end
		end
	end

	for _, startTime in ipairs(lines) do
		local timePoint = self.foregroundLayerData:getTimePoint(startTime / 1000)

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
