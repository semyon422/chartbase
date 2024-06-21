local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Bms = require("bms.BMS")
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
local enums = require("bms.enums")
local Ksh = require("ksm.Ksh")

---@class ksm.ChartDecoder: chartbase.IChartDecoder
---@operator call: ksm.ChartDecoder
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
	local ksh = Ksh(s)
	local content = s:gsub("\r\n", "\n")
	content = self.conv:convert(content)
	ksh:import(content)
	local chart = self:decodeKsh(ksh)
	return {chart}
end

---@param ksh ksm.Ksh
---@return ncdk2.Chart
function ChartDecoder:decodeKsh(ksh)
	self.ksh = ksh

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	chart.inputMode = InputMode({
		bt = 4,
		fx = 2,
		laserleft = 2,
		laserright = 2,
	})

	self:processTempos()
	self:processSignatures()
	self:processNotes()
	self:processAudio()
	self:processMeasureLines()

	chart.type = "ksm"
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
	local ksh = self.ksh
	local options = ksh.options
	self.chart.chartmeta = Chartmeta({
		format = "ksh",
		title = options["title"],
		artist = options["artist"],
		name = options["difficulty"],
		creator = options["effect"],
		level = tonumber(options["level"]),
		tempo = tonumber(options["t"]) or 0,
		audio_path = self.audioFileName,
		background_path = options["jacket"],
		preview_time = (options["plength"] or 0) / 1000,
		notes_count = self.notes_count,
		duration = self.totalLength,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.minTime,
	})
end

function ChartDecoder:processTempos()
	local layer = self.layer
	for _, _tempo in ipairs(self.ksh.tempos) do
		local measureTime = Fraction(_tempo.lineOffset, _tempo.lineCount) + _tempo.measureOffset
		local point = layer:getPoint(measureTime)
		point._tempo = Tempo(_tempo.tempo)
	end
end

function ChartDecoder:processSignatures()
	local layer = self.layer
	for _, _signature in ipairs(self.ksh.timeSignatures) do
		local measureTime = Fraction(_signature.measureIndex)
		local point = layer:getPoint(measureTime)
		point._signature = Signature(Fraction(_signature.n * 4, _signature.d))
	end
end

function ChartDecoder:processAudio()
	local audio = self.ksh.options.m
	local split = audio:split(";")
	if split[1] then
		audio = split[1]
	end
	if not audio then
		return
	end

	local audio_layer = AbsoluteLayer()
	self.chart.layers.audio = audio_layer

	local offset = -(tonumber(self.ksh.options.o) or 0) / 1000
	local visualPoint = audio_layer.visual:getPoint(audio_layer:getPoint(offset))

	local note = Note(visualPoint)
	note.noteType = "SoundNote"
	note.sounds = {{audio, 1}}
	note.stream = true
	note.streamOffset = offset
	self.chart.resourceList:add("sound", audio, {audio})

	audio_layer.notes:insert(note, "audio")
end

function ChartDecoder:processNotes()
	local layer = self.layer

	self.notes_count = 0

	self.minPoint = nil
	self.maxPoint = nil

	local allNotes = {}
	for _, note in ipairs(self.ksh.notes) do
		allNotes[#allNotes + 1] = note
	end
	for _, laser in ipairs(self.ksh.lasers) do
		allNotes[#allNotes + 1] = laser
	end

	for _, _note in ipairs(allNotes) do
		local startMeasureTime = Fraction(_note.startLineOffset, _note.startLineCount) + _note.startMeasureOffset
		local point = layer:getPoint(startMeasureTime)
		local visualPoint = layer.visual:getPoint(point)

		local startNote = Note(visualPoint)
		local inputType = _note.input
		local inputIndex = _note.lane
		if inputType == "fx" then
			inputIndex = _note.lane - 4
		end

		startNote.sounds = {}

		layer.notes:insert(startNote, inputType .. inputIndex)

		local lastPoint = point
		local endMeasureTime = Fraction(_note.endLineOffset, _note.endLineCount) + _note.endMeasureOffset

		if startMeasureTime == endMeasureTime then
			startNote.noteType = "ShortNote"
		else
			if _note.input ~= "laser" then
				startNote.noteType = "LongNoteStart"
			else
				startNote.noteType = "LaserNoteStart"
			end

			local end_point = layer:getPoint(endMeasureTime)
			local end_visualPoint = layer.visual:getPoint(end_point)

			local endNote = Note(end_visualPoint)
			endNote.sounds = {}

			if _note.input ~= "laser" then
				endNote.noteType = "LongNoteEnd"
			else
				endNote.noteType = "LaserNoteEnd"
			end

			endNote.startNote = startNote
			startNote.endNote = endNote

			layer.notes:insert(endNote, inputType .. inputIndex)

			lastPoint = end_point
		end

		self.notes_count = self.notes_count + 1

		if not self.minPoint or point < self.minPoint then
			self.minPoint = point
		end
		if not self.maxPoint or lastPoint > self.maxPoint then
			self.maxPoint = lastPoint
		end
	end
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	for measureIndex = 0, #self.ksh.measureStrings do
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
