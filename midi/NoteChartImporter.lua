local class = require("class")
local ncdk = require("ncdk")
local Fraction = require("ncdk.Fraction")
local NoteChart = require("ncdk.NoteChart")
local UnifiedMetaData = require("notechart.UnifiedMetaData")
local MID = require("midi.MID")
local EncodingConverter = require("notechart.EncodingConverter")

---@class midi.NoteChartImporter
---@operator call: midi.NoteChartImporter
local NoteChartImporter = class()

function NoteChartImporter:new()
	self.layerDatas = {}
end

function NoteChartImporter:import()
	local noteChart = NoteChart()
	noteChart.inputMode.key = 88
	noteChart.type = "midi"
	self.noteCharts = {noteChart}

	local fileName = self.path:match("^.+/(.-)$")
	self.title = fileName:match("^(.+)%..-$")

	local hitsounds = love.filesystem.getDirectoryItems("userdata/hitsounds/midi")
	self.hitsoundType = hitsounds[1]:match("^.+(%..+)$")
	self.hitsoundFormat = tonumber(hitsounds[1]:sub(1, 1)) ~= nil and "numbs" or "keys"
	if self.hitsoundFormat == "keys" then
		NoteChartImporter:fillKeys()
	end

	if not self.mid then
		self.mid = MID(self.content)
	end

	local addedNotes = {}
	self.noteCount = 0
	for i = 1, #self.mid.notes do
		self:processData(i, self:createLayerData(i), addedNotes)
	end

	self:processMeasureLines()

	noteChart:compute()

	local mid = self.mid
	noteChart.metaData = UnifiedMetaData({
		format = "mid",
		title = EncodingConverter:fix(self.title),
		noteCount = self.noteCount,
		length = mid.length,
		bpm = mid.bpm,
		inputMode = tostring(noteChart.inputMode),
		minTime = mid.minTime,
		maxTime = mid.maxTime
	})
end

function NoteChartImporter:fillKeys()
	local keyLabels = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

	local keys = {"A1","A#1","B1"}
	for i = 2, 8 do
		for _, label in ipairs(keyLabels) do
			keys[#keys+1] = label .. i
		end
	end

	self.keys = keys
end

---@param index number
---@return ncdk.LayerData
function NoteChartImporter:createLayerData(index)
	index = index or #self.layerDatas + 1

	local layerData = self.noteCharts[1]:getLayerData(index)
	layerData:setTimeMode("measure")
	layerData:setSignatureMode("short")
	layerData:setPrimaryTempo(120)

	layerData:setSignature(0, Fraction:new(4))

	for _, tempo in ipairs(self.mid.tempos) do
		layerData:insertTempoData(Fraction:new(tempo[1], 1000, true), tempo[2])
	end

	self.layerDatas[index] = layerData

	return layerData
end

---@param trackIndex number
---@param layerData ncdk.LayerData
---@param addedNotes table
function NoteChartImporter:processData(trackIndex, layerData, addedNotes)
	local notes = self.mid.notes
	local noteChart = self.noteCharts[1]
	local constantVolume = self.settings and self.settings["midiConstantVolume"] or false
	local hitsoundType = self.hitsoundType
	local hitsoundFormat = self.hitsoundFormat
	local keys = self.keys
	local noteCount = self.noteCount

	local prevEvents = {}
	for i = 1, 88 do
		prevEvents[i] = false
	end

	local hitsoundPath
	local startEvent
	local startNoteData
	local endNoteData
	for _, event in ipairs(notes[trackIndex]) do
		if event[1] then
			prevEvents[event[3]] = event
		else
			startEvent = prevEvents[event[3]]
			if startEvent and not startEvent.used then
				local eventId = startEvent[2] .. ":" .. startEvent[3]

				hitsoundPath = hitsoundFormat == "numbs" and tostring(event[3]) or keys[event[3]]
				if event[2] - startEvent[2] > 0.2 then
					hitsoundPath = hitsoundPath .. "R"
				end
				hitsoundPath = hitsoundPath .. hitsoundType
				noteChart:addResource("sound", hitsoundPath, {hitsoundPath})

				local inputType, inputIndex

				startNoteData = ncdk.NoteData(layerData:getTimePoint(Fraction:new(startEvent[2], 1000, true)))
				startNoteData.sounds = {{hitsoundPath, constantVolume and 1 or startEvent[4]}}
				if addedNotes[eventId] then
					inputType = "auto"
					inputIndex = 0
					startNoteData.noteType = "SoundNote"
				else
					inputType = "key"
					inputIndex = startEvent[3]
					startNoteData.noteType = "LongNoteStart"
				end

				layerData:addNoteData(startNoteData, inputType, inputIndex)

				startEvent.used = true

				endNoteData = ncdk.NoteData(layerData:getTimePoint(Fraction:new(event[2], 1000, true)))
				endNoteData.sounds = {{"none" .. hitsoundType, 0}}
				if addedNotes[eventId] then
					inputType = "auto"
					inputIndex = 0
					endNoteData.noteType = "SoundNote"
				else
					inputType = "key"
					inputIndex = event[3]
					endNoteData.noteType = "LongNoteEnd"
				end

				startNoteData.endNoteData = endNoteData
				endNoteData.startNoteData = startNoteData

				layerData:addNoteData(endNoteData, inputType, inputIndex)

				noteCount = noteCount + 1
				addedNotes[eventId] = true
			end
		end
	end

	self.noteCount = noteCount
end

function NoteChartImporter:processMeasureLines()
	local LayerData = self.layerDatas[1]
	local minTime = self.mid.minTime
	local maxTime = self.mid.maxTime

	local time = minTime

	local i = 1
	while time < maxTime do
		local timePoint = LayerData:getTimePoint(Fraction:new(time, 1000, true))
		local startNoteData = ncdk.NoteData(timePoint)
		startNoteData.noteType = "LineNoteStart"

		local endNoteData = ncdk.NoteData(timePoint)
		endNoteData.noteType = "LineNoteEnd"

		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData

		LayerData:addNoteData(startNoteData, "measure", 1)
		LayerData:addNoteData(endNoteData, "measure", 1)

		time = (i * 0.5) + minTime
		i = i + 1
	end
end

return NoteChartImporter
