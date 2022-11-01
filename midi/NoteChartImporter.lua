local ncdk = require("ncdk")
local Fraction = require("ncdk.Fraction")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local MID = require("midi.MID")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	self.LayerDatas = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self)
	local noteChart = NoteChart:new()
	noteChart.inputMode.key = 88
	noteChart.type = "midi"
	self.noteCharts = {noteChart}

	self.title = self.path:match("^.*/(.*).mid$")

	local hitsounds = love.filesystem.getDirectoryItems("userdata/hitsounds/midi")
	self.hitsoundType = hitsounds[1]:match("^.+(%..+)$")
	self.hitsoundFormat = tonumber(hitsounds[1]:sub(1, 1)) ~= nil and "numbs" or "keys"
	if self.hitsoundFormat == "keys" then
		NoteChartImporter:fillKeys()
	end

	if not self.mid then
		self.mid = MID:new(self.content)
	end

	local addedNotes = {}
	self.noteCount = 0
	for i = 1, #self.mid.notes do
		self:processData(i, self:createLayerData(i), addedNotes)
	end

	self:processMeasureLines()

	noteChart:compute()
	noteChart.index = 1
	noteChart.metaData = MetaData(noteChart, self)
end

NoteChartImporter.fillKeys = function(self)
	local keyLabels = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

	local keys = {"A1","A#1","B1"}
	for i = 2, 8 do
		for _, label in ipairs(keyLabels) do
			keys[#keys+1] = label .. i
		end
	end

	self.keys = keys
end

NoteChartImporter.createLayerData = function(self, index)
	local index = index or #self.LayerDatas + 1

	local LayerData = self.noteCharts[1].layerDataSequence:requireLayerData(index)
	LayerData:setTimeMode("measure")
	LayerData:setSignatureMode("short")

	LayerData:setSignature(0, Fraction:new(4))

	for _, tempo in ipairs(self.mid.tempos) do
		LayerData:addTempoData(
			ncdk.TempoData:new(
				Fraction:new(tempo[1], 1000, true),
				tempo[2]
			)
		)
	end

	local velocityData = ncdk.VelocityData:new(
		LayerData:getTimePoint(
			Fraction:new(0),
			-1
		)
	)
	velocityData.currentVelocity = 1
	LayerData:addVelocityData(velocityData)

	self.LayerDatas[index] = LayerData

	return LayerData
end

NoteChartImporter.processData = function(self, trackIndex, LayerData, addedNotes)
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

				startNoteData = ncdk.NoteData:new(LayerData:getTimePoint(
						Fraction:new(startEvent[2], 1000, true),
						-1
					)
				)
				startNoteData.sounds = {{hitsoundPath, constantVolume and 1 or startEvent[4]}}
				if addedNotes[eventId] then
					startNoteData.inputType = "auto"
					startNoteData.noteType = "SoundNote"
					startNoteData.inputIndex = 0
				else
					startNoteData.inputType = "key"
					startNoteData.noteType = "LongNoteStart"
					startNoteData.inputIndex = startEvent[3]
				end

				startEvent.used = true

				endNoteData = ncdk.NoteData:new(LayerData:getTimePoint(
						Fraction:new(event[2], 1000, true),
						-1
					)
				)
				endNoteData.sounds = {{"none" .. hitsoundType, 0}}
				if addedNotes[eventId] then
					endNoteData.inputType = "auto"
					endNoteData.noteType = "SoundNote"
					endNoteData.inputIndex = 0
				else
					endNoteData.inputType = "key"
					endNoteData.noteType = "LongNoteEnd"
					endNoteData.inputIndex = event[3]
				end

				startNoteData.endNoteData = endNoteData
				endNoteData.startNoteData = startNoteData

				LayerData:addNoteData(startNoteData)
				LayerData:addNoteData(endNoteData)

				noteCount = noteCount + 1
				addedNotes[eventId] = true
			end
		end
	end

	self.noteCount = noteCount
end

NoteChartImporter.processMeasureLines = function(self)
	local LayerData = self.LayerDatas[1]
	local minTime = self.mid.minTime
	local maxTime = self.mid.maxTime

	local time = minTime

	local i = 1
	while time < maxTime do
		local timePoint = LayerData:getTimePoint(
			Fraction:new(time, 1000, true),
			-1
		)

		local startNoteData = ncdk.NoteData:new(timePoint)
		startNoteData.inputType = "measure"
		startNoteData.inputIndex = 1
		startNoteData.noteType = "LineNoteStart"

		local endNoteData = ncdk.NoteData:new(timePoint)
		endNoteData.inputType = "measure"
		endNoteData.inputIndex = 1
		endNoteData.noteType = "LineNoteEnd"

		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData

		LayerData:addNoteData(startNoteData)
		LayerData:addNoteData(endNoteData)

		time = (i * 0.5) + minTime
		i = i + 1
	end
end

return NoteChartImporter
