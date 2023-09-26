local class = require("class")
local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local UnifiedMetaData = require("notechart.UnifiedMetaData")
local OJN = require("o2jam.OJN")
local bmsNoteChartImporter = require("bms.NoteChartImporter")
local EncodingConverter = require("notechart.EncodingConverter")

---@class o2jam.NoteChartImporter
---@operator call: o2jam.NoteChartImporter
local NoteChartImporter = class()

NoteChartImporter.primaryTempo = 120
NoteChartImporter.measureCount = 0

local O2jamDifficultyNames = {"Easy", "Normal", "Hard"}

function NoteChartImporter:import()
	local noteCharts = {}

	local ojn = OJN(self.content)

	local i0, i1 = 1, 3
	if self.index then
		i0, i1 = self.index, self.index
	end

	for i = i0, i1 do
		local importer = NoteChartImporter()
		importer.ojn = ojn
		noteCharts[#noteCharts + 1] = importer:importSingle(i)
	end

	self.noteCharts = noteCharts
end

---@param index number
---@return ncdk.NoteChart
function NoteChartImporter:importSingle(index)
	self.chartIndex = index

	self.noteChart = NoteChart()
	local noteChart = self.noteChart

	if not self.ojn then
		self.ojn = OJN(self.content)
	end

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")
	self.foregroundLayerData:setSignatureMode("short")
	self.foregroundLayerData:setPrimaryTempo(120)

	self:processData()

	self:processMeasureLines()

	noteChart.inputMode.key = 7
	noteChart.type = "o2jam"

	noteChart:compute()

	self:updateLength()

	local ojn = self.ojn
	noteChart.index = index
	noteChart.metaData = UnifiedMetaData({
		index = index,
		format = "ojn",
		title = EncodingConverter:fix(ojn.str_title),
		artist = EncodingConverter:fix(ojn.str_artist),
		name = O2jamDifficultyNames[index],
		creator = EncodingConverter:fix(ojn.str_noter),
		level = ojn.charts[index].level,
		noteCount = ojn.charts[index].notes,
		length = ojn.charts[index].duration,
		bpm = ojn.bpm,
		inputMode = tostring(noteChart.inputMode),
		minTime = self.minTime,
		maxTime = self.maxTime
	})

	return noteChart
end

NoteChartImporter.updateLength = bmsNoteChartImporter.updateLength

function NoteChartImporter:addFirstTempo()
	local ld = self.foregroundLayerData
	local measureTime = ncdk.Fraction(0)
	ld:insertTempoData(measureTime, self.ojn.bpm)
end

function NoteChartImporter:processData()
	local longNoteData = {}

	self.noteCount = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil
	self.tempoAtStart = false

	local ld = self.foregroundLayerData

	local measureCount = self.ojn.charts[self.chartIndex].measure_count

	for _, event in ipairs(self.ojn.charts[self.chartIndex].event_list) do
		local measureTime = ncdk.Fraction(event.measure + event.position, 1000, true)
		if event.measure < 0 or event.measure > measureCount * 2 then
			-- ignore
		elseif event.channel == "BPM_CHANGE" then
			if measureTime:tonumber() == 0 then
				self.tempoAtStart = true
			end

			ld:insertTempoData(measureTime, event.value)
		elseif event.channel == "TIME_SIGNATURE" then
			ld:setSignature(
				event.measure,
				ncdk.Fraction:new(event.value * 4, 32768, true)
			)
		elseif event.channel:find("NOTE") or event.channel:find("AUTO") then
			local timePoint = ld:getTimePoint(measureTime)

			local noteData = ncdk.NoteData(timePoint)
			local inputType = event.channel:find("NOTE") and "key" or "auto"
			local inputIndex = event.channel:find("NOTE") and tonumber(event.channel:sub(-1, -1)) or 0

			if inputType == "auto" then
				noteData.noteType = "SoundNote"
				noteData.sounds = {{event.value, event.volume}}
				ld:addNoteData(noteData, inputType, inputIndex)
			else
				if event.measure > self.measureCount then
					self.measureCount = event.measure
				end
				if longNoteData[inputIndex] and event.type == "RELEASE" then
					longNoteData[inputIndex].noteType = "LongNoteStart"
					longNoteData[inputIndex].endNoteData = noteData
					noteData.startNoteData = longNoteData[inputIndex]
					noteData.noteType = "LongNoteEnd"
					longNoteData[inputIndex] = nil
					noteData.sounds = {}
				else
					noteData.noteType = "ShortNote"
					if event.type == "HOLD" then
						longNoteData[inputIndex] = noteData
					end

					self.noteCount = self.noteCount + 1
					noteData.sounds = {{event.value, event.volume}}
				end
				if not self.minTimePoint or timePoint < self.minTimePoint then
					self.minTimePoint = timePoint
				end
				if not self.maxTimePoint or timePoint > self.maxTimePoint then
					self.maxTimePoint = timePoint
				end
				ld:addNoteData(noteData, inputType, inputIndex)
			end
		end
	end

	if not self.tempoAtStart then
		self:addFirstTempo()
	end
end

function NoteChartImporter:processMeasureLines()
	for measureIndex = 0, self.measureCount do
		local measureTime = ncdk.Fraction(measureIndex)
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime)

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
