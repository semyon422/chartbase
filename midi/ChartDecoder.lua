local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Bms = require("bms.BMS")
local Note = require("notechart.Note")
local Signature = require("ncdk2.to.Signature")
local Tempo = require("ncdk2.to.Tempo")
local Stop = require("ncdk2.to.Stop")
local MeasureLayer = require("ncdk2.layers.MeasureLayer")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Chartmeta = require("notechart.Chartmeta")
local EncodingConverter = require("notechart.EncodingConverter")
local enums = require("bms.enums")
local Mid = require("midi.MID")

---@class midi.ChartDecoder: chartbase.IChartDecoder
---@operator call: midi.ChartDecoder
local ChartDecoder = IChartDecoder + {}

---@param s string
---@return ncdk2.Chart[]
function ChartDecoder:decode(s)
	local mid = Mid(s)
	local chart = self:decodeMid(mid)
	return {chart}
end

---@param mid midi.MID
---@return ncdk2.Chart
function ChartDecoder:decodeMid(mid)
	self.mid = mid

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	for _, tempo in ipairs(mid.tempos) do
		local point = layer:getPoint(Fraction(tempo[1], 1000, true))
		point._tempo = Tempo(tempo[2])
	end

	chart.inputMode = InputMode({key = 88})

	local addedNotes = {}
	self.notes_count = 0
	for i = 1, #self.mid.notes do
		self:processData(i, addedNotes)
	end

	self:processMeasureLines()

	chart.type = "bms"
	chart:compute()

	self:setMetadata()

	return chart
end

function ChartDecoder:setMetadata()
	local mid = self.mid
	self.chart.chartmeta = Chartmeta({
		format = "mid",
		title = self.title,
		notes_count = self.notes_count,
		duration = mid.length,
		tempo = mid.bpm,
		inputmode = tostring(self.chart.inputMode),
		start_time = mid.minTime,
	})
end

---@param trackIndex number
---@param addedNotes table
function ChartDecoder:processData(trackIndex, addedNotes)
	local notes = self.mid.notes
	local chart = self.chart
	local layer = self.layer
	local notes_count = self.notes_count

	local startNote
	for _, event in ipairs(notes[trackIndex]) do
		if event[1] then
			local eventId = event[2] .. ":" .. event[3]

			local hs = tostring(event[3])
			chart.resourceList:add("sound", hs, {hs})

			local point = layer:getPoint(Fraction(event[2], 1000, true))
			startNote = Note(layer.visual:getPoint(point))
			startNote.sounds = {{hs, event[4]}}

			if addedNotes[eventId] then
				startNote.noteType = "SoundNote"
				layer.notes:insert(startNote, "auto0")
			else
				startNote.noteType = "ShortNote"
				layer.notes:insert(startNote, "key" .. event[3])
			end

			-- TODO: long notes?

			notes_count = notes_count + 1
			addedNotes[eventId] = true
		end
	end

	self.notes_count = notes_count
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	local minTime = self.mid.minTime
	local maxTime = self.mid.maxTime

	local time = minTime

	-- TODO
end

return ChartDecoder
