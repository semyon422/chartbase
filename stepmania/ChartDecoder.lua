local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Note = require("notechart.Note")
local Signature = require("ncdk2.to.Signature")
local Tempo = require("ncdk2.to.Tempo")
local Stop = require("ncdk2.to.Stop")
local MeasureLayer = require("ncdk2.layers.MeasureLayer")
local AbsoluteLayer = require("ncdk2.layers.AbsoluteLayer")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Chartmeta = require("notechart.Chartmeta")
local EncodingConverter = require("notechart.EncodingConverter")
local dpairs = require("dpairs")
local Sm = require("stepmania.SM")

---@class stepmania.ChartDecoder: chartbase.IChartDecoder
---@operator call: stepmania.ChartDecoder
local ChartDecoder = IChartDecoder + {}

local encodings = {
	"SHIFT-JIS",
	"ISO-8859-1",
	"CP932",
	"EUC-KR",
	"US-ASCII",
	"CP1252",
}

function ChartDecoder:new()
	self.conv = EncodingConverter(encodings)
end

---@param s string
---@return ncdk2.Chart[]
function ChartDecoder:decode(s)
	local sm = Sm()
	local content = s:gsub("\r[\r\n]?", "\n")
	content = self.conv:convert(content)
	sm:import(content)

	---@type ncdk2.Chart[]
	local charts = {}
	for i = 1, #sm.charts do
		charts[i] = self:decodeSm(sm, i)
	end
	return charts
end

---@param sm stepmania.SM
---@param index integer
---@return ncdk2.Chart
function ChartDecoder:decodeSm(sm, index)
	self.sm = sm
	self.sm_chart = sm.charts[index]

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	chart.inputMode = InputMode({key = self.sm_chart.mode})
	self:processTempo()
	self:processNotes()
	self:processAudio()
	self:processMeasureLines()

	chart.type = "sm"
	chart:compute()

	self:updateLength()
	self:setMetadata()

	return chart
end

function ChartDecoder:updateLength()
	if self.maxPoint and self.minPoint then
		self.totalLength = self.maxPoint.absoluteTime - self.minPoint.absoluteTime
		self.minTime = self.minPoint.absoluteTime
		self.maxTime = self.maxPoint.absoluteTime
	else
		self.totalLength = 0
		self.minTime = 0
		self.maxTime = 0
	end
end

function ChartDecoder:setMetadata()
	local sm = self.sm
	local sm_chart = self.sm_chart
	local header = sm.header
	self.chart.chartmeta = Chartmeta({
		format = "sm",
		title = header["TITLE"],
		artist = header["ARTIST"],
		source = header["SUBTITLE"],
		name = sm_chart.header[3],
		creator = header["CREDIT"],
		level = tonumber(sm_chart.header[4]),
		audio_path = header["MUSIC"],
		audio_offset = tonumber(self.sm.header["OFFSET"]),
		preview_time = tonumber(header["SAMPLESTART"]) or 0,
		background_path = header["BACKGROUND"],
		notes_count = self.notes_count,
		duration = self.totalLength,
		tempo = self.sm.displayTempo or 0,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.minTime,
	})
end

function ChartDecoder:processNotes()
	local layer = self.layer
	self.notes_count = 0

	self.minPoint = nil
	self.maxPoint = nil

	local longNotes = {}
	for _, _note in ipairs(self.sm_chart.notes) do
		local measureTime = Fraction(_note.offset, self.sm_chart.linesPerMeasure[_note.measure]) + _note.measure
		local point = layer:getPoint(measureTime)
		local visualPoint = layer.visual:getPoint(point)

		local note = Note(visualPoint)

		note.sounds = {}
		note.images = {}

		if _note.noteType == "1" then
			note.noteType = "ShortNote"
			self.notes_count = self.notes_count + 1
		elseif _note.noteType == "M" or _note.noteType == "F" then
			note.noteType = "SoundNote"
		elseif _note.noteType == "2" or _note.noteType == "4" then
			note.noteType = "ShortNote"
			longNotes[_note.column] = note
			self.notes_count = self.notes_count + 1
		elseif _note.noteType == "3" then
			note.noteType = "LongNoteEnd"
			note.startNote = longNotes[_note.column]
			longNotes[_note.column].endNote = note
			longNotes[_note.column].noteType = "LongNoteStart"
			longNotes[_note.column] = nil
		end

		layer.notes:insert(note, "key" .. _note.column)

		if not self.minPoint or point < self.minPoint then
			self.minPoint = point
		end

		if not self.maxPoint or point > self.maxPoint then
			self.maxPoint = point
		end
	end
end

function ChartDecoder:processTempo()
	local layer = self.layer
	for _, bpm in ipairs(self.sm.bpm) do
		local measureTime = Fraction(bpm.beat / 4, 1000, true)
		local point = layer:getPoint(measureTime)
		point._tempo = Tempo(bpm.tempo)
		layer.visual:getPoint(point)
	end
	for _, stop in ipairs(self.sm.stop) do
		local measureTime = Fraction(stop.beat / 4, 1000, true)
		local point = layer:getPoint(measureTime)
		point._stop = Stop(stop.duration, true)
		layer.visual:getPoint(point)
	end
end

function ChartDecoder:processAudio()
	local audio_layer = AbsoluteLayer()
	self.chart.layers.audio = audio_layer

	local offset = tonumber(self.sm.header["OFFSET"]) or 0
	local visualPoint = audio_layer.visual:getPoint(audio_layer:getPoint(offset))

	local note = Note(visualPoint)
	note.noteType = "SoundNote"
	note.sounds = {{self.sm.header["MUSIC"], 1}}
	note.stream = true
	note.streamOffset = offset
	self.chart.resourceList:add("sound", self.sm.header["MUSIC"], {self.sm.header["MUSIC"]})

	audio_layer.notes:insert(note, "audio")
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	for measureIndex = 0, self.sm_chart.measure do
		local point = layer:getPoint(Fraction(measureIndex))

		local startNote = Note(layer.visual:getPoint(point))
		startNote.noteType = "LineNoteStart"
		layer.notes:insert(startNote, "measure1")

		local endNote = Note(layer.visual:newPoint(point))
		endNote.noteType = "LineNoteEnd"
		layer.notes:insert(endNote, "measure1")

		startNote.endNote = endNote
		endNote.startNote = startNote
	end
end

return ChartDecoder
