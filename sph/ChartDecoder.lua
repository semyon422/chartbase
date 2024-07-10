local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Sph = require("sph.Sph")
local Note = require("notechart.Note")
local Velocity = require("ncdk2.visual.Velocity")
local Expand = require("ncdk2.visual.Expand")
local Measure = require("ncdk2.to.Measure")
local Interval = require("ncdk2.to.Interval")
local IntervalLayer = require("ncdk2.layers.IntervalLayer")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Chartmeta = require("notechart.Chartmeta")
local Visual = require("ncdk2.visual.Visual")

---@class sph.ChartDecoder: chartbase.IChartDecoder
---@operator call: sph.ChartDecoder
local ChartDecoder = IChartDecoder + {}

function ChartDecoder:new()
	self.notes_count = 0
	self.longNotes = {}
end

---@param s string
---@return ncdk2.Chart[]
function ChartDecoder:decode(s)
	local sph = Sph()
	sph:decode(s:gsub("\r[\r\n]?", "\n"))
	local chart = self:decodeSph(sph)
	return {chart}
end

---@param sph sph.Sph
---@return ncdk2.Chart
function ChartDecoder:decodeSph(sph)
	self.sph = sph

	local chart = Chart()
	self.chart = chart

	chart.inputMode = InputMode(sph.metadata.input)
	self.inputMap = chart.inputMode:getInputMap()

	local layer = IntervalLayer()
	chart.layers.main = layer
	self.layer = layer

	for _, line in ipairs(sph.sphLines.protoLines) do
		self:processLine(line)
	end

	self:addAudio()

	chart.type = "bms"
	chart:compute()

	self:setMetadata()

	return chart
end

---@param name string?
function ChartDecoder:getVisual(name)
	name = name or ""
	local visual = self.layer.visuals[name]
	if visual then
		return visual
	end

	visual = Visual()
	self.layer.visuals[name] = visual

	return visual
end

---@param line table
function ChartDecoder:processLine(line)
	local layer = self.layer
	local chart = self.chart
	local longNotes = self.longNotes
	local sounds = self.sph.sounds
	local inputMap = self.inputMap

	local visual = self:getVisual(line.visual)

	local point = layer:getPoint(line.globalTime)
	local visualPoint = visual:newPoint(point)

	if line.offset then
		point._interval = Interval(line.offset)
	end

	point.comment = line.comment

	local line_sounds = line.sounds or {}
	local line_volume = line.volume or {}
	local notes = line.notes or {}

	for i, _note in ipairs(notes) do
		local col = _note.column
		local input = inputMap[col]
		local column = input[1] .. input[2]

		local note = Note(visualPoint, column)

		local sound = sounds[line_sounds[i]]
		if sound then
			note.sounds = {{sound, line_volume[i] or 1}}
			self.chart.resourceList:add("sound", sound, {sound})
		end

		local t = _note.type
		if t == "1" then
			note.noteType = "ShortNote"
			self.notes_count = self.notes_count + 1
		elseif t == "2" then
			note.noteType = "ShortNote"
			self.notes_count = self.notes_count + 1
			longNotes[col] = note
		elseif t == "3" and longNotes[col] then
			note.noteType = "LongNoteEnd"
			note.startNote = longNotes[col]
			longNotes[col].endNote = note
			longNotes[col].noteType = "LongNoteStart"
			longNotes[col] = nil
		elseif t == "4" then
			note.noteType = "SoundNote"
		end

		chart.notes:insert(note)
	end

	for i = #notes + 1, #line_sounds do
		local sound = sounds[line_sounds[i]]
		if sound then
			local column = "auto" .. (i - #notes)
			local note = Note(visualPoint, column)
			note.noteType = "SoundNote"
			note.sounds = {{sound, line_volume[i] or 1}}
			self.chart.resourceList:add("sound", sound, {sound})
			chart.notes:insert(note)
		end
	end

	if line.velocity then
		visualPoint._velocity = Velocity(unpack(line.velocity, 1, 3))
	end
	if line.expand and line.expand ~= 0 then
		visualPoint._expand = Expand(line.expand)
	end
	if line.measure then
		point._measure = Measure(line.measure)
	end

	if #notes > 0 then
		self:updateBoundaries(point)
	end
end

---@param point ncdk2.IntervalPoint
function ChartDecoder:updateBoundaries(point)
	if not self.minTimePoint or point < self.minTimePoint then
		self.minTimePoint = point
	end
	if not self.maxTimePoint or point > self.maxTimePoint then
		self.maxTimePoint = point
	end
end

function ChartDecoder:addAudio()
	local sph = self.sph
	local audio = sph.metadata.audio
	if not audio then
		return
	end

	local layer = IntervalLayer()
	self.chart.layers.audio = layer

	local visual = Visual()
	layer.visuals.main = visual

	local point = layer:getPoint(Fraction(0))
	point._interval = Interval(0)
	local vp = visual:getPoint(point)

	local note = Note(vp, "audio")
	note.sounds = {{audio, 1}}
	note.stream = true
	self.chart.resourceList:add("sound", audio, {audio})

	note.noteType = "SoundNote"
	self.chart.notes:insert(note)
end

function ChartDecoder:setMetadata()
	local chart = self.chart
	local sph = self.sph

	local totalLength, minTime, maxTime = 0, 0, 0
	if self.maxTimePoint then
		totalLength = self.maxTimePoint.absoluteTime - self.minTimePoint.absoluteTime
		minTime = self.minTimePoint.absoluteTime
		maxTime = self.maxTimePoint.absoluteTime
	end

	local layer = self.chart.layers.main

	---@type ncdk2.IntervalPoint[]
	local points = layer:getPointList()

	local a = points[1]
	local b = points[#points]
	local beats = (b.time - a.time):tonumber()
	local avgBeatDuration = (b.absoluteTime - a.absoluteTime) / beats

	chart.chartmeta = Chartmeta({
		format = "sph",
		title = sph.metadata.title,
		artist = sph.metadata.artist,
		source = sph.metadata.source,
		tags = sph.metadata.tags,
		name = sph.metadata.name,
		creator = sph.metadata.creator,
		level = tonumber(sph.metadata.level),
		audio_path = sph.metadata.audio,
		background_path = sph.metadata.background,
		preview_time = tonumber(sph.metadata.preview),
		notes_count = tonumber(self.notes_count),
		duration = tonumber(totalLength),
		tempo = 60 / avgBeatDuration,
		inputmode = sph.metadata.input,
		start_time = tonumber(minTime),
	})
end

return ChartDecoder
