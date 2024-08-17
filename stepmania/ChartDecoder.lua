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
local Sm = require("stepmania.Sm")
local Visual = require("ncdk2.visual.Visual")

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

---@param sm stepmania.Sm
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

	local visual = Visual()
	layer.visuals.main = visual
	self.visual = visual

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
		name = sm_chart.header.difficulty,
		creator = header["CREDIT"],
		level = tonumber(sm_chart.header.difficulty),
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
	local visual = self.visual
	local layer = self.layer
	local chart = self.chart
	self.notes_count = 0

	self.minPoint = nil
	self.maxPoint = nil

	local longNotes = {}
	for _, _note in ipairs(self.sm_chart.notes) do
		local measureTime = Fraction(_note.offset, self.sm_chart.measure_size[_note.measure]) + _note.measure
		local point = layer:getPoint(measureTime)
		local visualPoint = visual:getPoint(point)

		local column = "key" .. _note.column
		local note = Note(visualPoint, column)

		note.sounds = {}
		note.images = {}

		if _note.noteType == "1" then
			note.type = "note"
			self.notes_count = self.notes_count + 1
		elseif _note.noteType == "M" then
			note.type = "mine"
		elseif _note.noteType == "F" then
			note.type = "fake"
		elseif _note.noteType == "2" or _note.noteType == "4" then
			note.type = "note"
			longNotes[_note.column] = note
			self.notes_count = self.notes_count + 1
		elseif _note.noteType == "3" then
			note.type = "hold"
			note.weight = -1
			longNotes[_note.column].type = "hold"
			longNotes[_note.column].weight = 1
			longNotes[_note.column] = nil
		end

		chart.notes:insert(note)

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
	local visual = self.visual
	for _, bpm in ipairs(self.sm.bpm) do
		local measureTime = Fraction(bpm.beat / 4, 1000, true)
		local point = layer:getPoint(measureTime)
		point._tempo = Tempo(bpm.tempo)
		visual:getPoint(point)
	end
	for _, stop in ipairs(self.sm.stop) do
		local measureTime = Fraction(stop.beat / 4, 1000, true)
		local point = layer:getPoint(measureTime)
		point._stop = Stop(stop.duration, true)
		visual:getPoint(point)
	end
end

function ChartDecoder:processAudio()
	local audio_layer = AbsoluteLayer()
	self.chart.layers.audio = audio_layer

	local visual = Visual()
	audio_layer.visuals.main = visual

	local offset = tonumber(self.sm.header["OFFSET"]) or 0
	local visualPoint = visual:getPoint(audio_layer:getPoint(offset))

	local note = Note(visualPoint, "audio", "sample")
	note.sounds = {{self.sm.header["MUSIC"], 1}}
	note.stream = true
	note.streamOffset = offset
	self.chart.resources:add("sound", self.sm.header["MUSIC"])

	self.chart.notes:insert(note)
end

function ChartDecoder:processMeasureLines()
	local visual = self.visual
	local layer = self.layer
	local chart = self.chart
	local column = "measure1"
	for measureIndex = 0, self.sm_chart.measure do
		local point = layer:getPoint(Fraction(measureIndex))
		local startNote = Note(visual:getPoint(point), column, "shade")
		chart.notes:insert(startNote)
	end
end

return ChartDecoder
