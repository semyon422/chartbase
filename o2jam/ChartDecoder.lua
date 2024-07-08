local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Ojn = require("o2jam.OJN")
local Note = require("notechart.Note")
local Signature = require("ncdk2.to.Signature")
local Tempo = require("ncdk2.to.Tempo")
local MeasureLayer = require("ncdk2.layers.MeasureLayer")
local VisualColumns = require("ncdk2.visual.VisualColumns")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Chartmeta = require("notechart.Chartmeta")
local EncodingConverter = require("notechart.EncodingConverter")

---@class o2jam.ChartDecoder: chartbase.IChartDecoder
---@operator call: o2jam.ChartDecoder
local ChartDecoder = IChartDecoder + {}

local O2jamDifficultyNames = {"Easy", "Normal", "Hard"}

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
	local ojn = Ojn(s)
	return {
		self:decodeOjn(ojn, 1),
		self:decodeOjn(ojn, 2),
		self:decodeOjn(ojn, 3),
	}
end

---@param ojn o2jam.OJN
---@param index integer
---@return ncdk2.Chart
function ChartDecoder:decodeOjn(ojn, index)
	self.ojn = ojn

	local chart = Chart()
	self.chart = chart

	chart.inputMode = InputMode({key = 7})

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer
	self.visualColumns = VisualColumns(layer.visual)

	self:process(index)
	self:processMeasureLines()

	chart.type = "o2jam"
	chart:compute()

	self:updateLength()
	self:setMetadata(index)

	return chart
end

---@param index integer
function ChartDecoder:setMetadata(index)
	local ojn = self.ojn
	self.chart.chartmeta = Chartmeta({
		format = "ojn",
		title = self.conv:convert(ojn.str_title),
		artist = self.conv:convert(ojn.str_artist),
		name = O2jamDifficultyNames[index],
		creator = self.conv:convert(ojn.str_noter),
		level = ojn.charts[index].level,
		-- notes_count = ojn.charts[index].notes,
		notes_count = self.notes_count,
		-- duration = ojn.charts[index].duration,
		duration = self.totalLength,
		tempo = ojn.bpm,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.minTime,
	})
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

---@param index integer
function ChartDecoder:process(index)
	---@type notechart.Note[]
	local long_notes = {}

	self.notes_count = 0
	self.measure_count = 0
	self.tempoAtStart = false
	self.minPoint = nil
	self.maxPoint = nil

	local layer = self.layer
	local visualColumns = self.visualColumns

	local measure_count = self.ojn.charts[index].measure_count

	for _, event in ipairs(self.ojn.charts[index].event_list) do
		local measureTime = event.position + event.measure
		local point = layer:getPoint(measureTime)
		local next_point = layer:getPoint(measureTime + 1)
		if event.measure < 0 or event.measure > measure_count * 2 then
			-- ignore
		elseif event.channel == "BPM_CHANGE" then
			if measureTime:tonumber() == 0 then
				self.tempoAtStart = true
			end
			point._tempo = Tempo(event.value)
			layer.visual:getPoint(point)
		elseif event.channel == "TIME_SIGNATURE" then
			point._signature = Signature(Fraction(event.value * 4, 32768, true))
			if not next_point._signature then
				next_point._signature = Signature()
			end
			layer.visual:getPoint(point)
			layer.visual:getPoint(next_point)
		elseif event.channel:find("NOTE") or event.channel:find("AUTO") then
			if event.channel:find("AUTO") then
				local visualPoint = visualColumns:getPoint(point, "auto")
				local note = Note(visualPoint)
				note.noteType = "SoundNote"
				note.sounds = {{event.value, event.volume}}
				layer.notes:insert(note, "auto")
			else
				local key = tonumber(event.channel:sub(-1, -1))
				local visualPoint = visualColumns:getPoint(point, "key" .. key)
				local note = Note(visualPoint)
				if event.measure > self.measure_count then
					self.measure_count = event.measure
				end
				if long_notes[key] and event.type == "RELEASE" then
					long_notes[key].noteType = "LongNoteStart"
					long_notes[key].endNote = note
					note.startNote = long_notes[key]
					note.noteType = "LongNoteEnd"
					long_notes[key] = nil
				else
					note.noteType = "ShortNote"
					if event.type == "HOLD" then
						long_notes[key] = note
					end

					self.notes_count = self.notes_count + 1
					note.sounds = {{event.value, event.volume}}
				end
				if not self.minPoint or point < self.minPoint then
					self.minPoint = point
				end
				if not self.maxPoint or point > self.maxPoint then
					self.maxPoint = point
				end
				layer.notes:insert(note, "key" .. key)
			end
		end
	end

	if not self.tempoAtStart then
		local point = layer:getPoint(Fraction(0))
		point._tempo = Tempo(self.ojn.bpm)
		layer.visual:getPoint(point)
	end
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	local visualColumns = self.visualColumns
	for measureIndex = 0, self.measure_count do
		local point = layer:getPoint(Fraction(measureIndex))

		local startNote = Note(visualColumns:getPoint(point, "measure1"))
		startNote.noteType = "LineNoteStart"
		layer.notes:insert(startNote, "measure1")

		local endNote = Note(visualColumns:getPoint(point, "measure1"))
		endNote.noteType = "LineNoteEnd"
		layer.notes:insert(endNote, "measure1")

		startNote.endNote = endNote
		endNote.startNote = startNote
	end
end

return ChartDecoder
