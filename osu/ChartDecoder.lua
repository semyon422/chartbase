local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Note = require("notechart.Note")
local Velocity = require("ncdk2.visual.Velocity")
local Tempo = require("ncdk2.to.Tempo")
local AbsoluteLayer = require("ncdk2.layers.AbsoluteLayer")
local VisualColumns = require("ncdk2.visual.VisualColumns")
local InputMode = require("ncdk.InputMode")
local Chartmeta = require("notechart.Chartmeta")
local RawOsu = require("osu.RawOsu")
local Osu = require("osu.Osu")
local Visual = require("ncdk2.visual.Visual")

---@class osu.ChartDecoder: chartbase.IChartDecoder
---@operator call: osu.ChartDecoder
local ChartDecoder = IChartDecoder + {}

function ChartDecoder:new()
	self.notes_count = 0
	self.longNotes = {}
end

---@param s string
---@return ncdk2.Chart[]
function ChartDecoder:decode(s)
	local rawOsu = RawOsu()
	local osu = Osu(rawOsu)
	rawOsu:decode(s)
	osu:decode()
	local chart = self:decodeOsu(osu)
	return {chart}
end

---@param osu osu.Osu
---@return ncdk2.Chart[]
function ChartDecoder:decodeOsu(osu)
	self.osu = osu

	local chart = Chart()
	self.chart = chart

	local layer = AbsoluteLayer()
	chart.layers.main = layer
	self.layer = layer

	local visual = Visual()
	layer.visuals.main = visual
	self.visual = visual
	self.visualColumns = VisualColumns(visual)

	visual.primaryTempo = 120

	self:decodeTempos()
	self:decodeVelocities()
	self:decodeNotes()
	self:decodeSamples()
	self:decodeBarlines()

	self:addAudio()

	local mode = tonumber(self.osu.rawOsu.General.Mode)
	if mode == 0 then
		chart.inputMode = InputMode({osu = 1})
	elseif mode == 1 then
		chart.inputMode = InputMode({key = 2})
	elseif mode == 2 then
		chart.inputMode = InputMode({fruits = 1})
	elseif mode == 3 then
		chart.inputMode = InputMode({key = osu.keymode})
	end
	chart.type = "osu"

	chart:compute()

	self:setMetadata()

	return chart
end

function ChartDecoder:setMetadata()
	local general = self.osu.rawOsu.General
	local metadata = self.osu.rawOsu.Metadata
	self.chart.chartmeta = Chartmeta({
		format = "osu",
		title = metadata.Title,
		artist = metadata.Artist,
		source = metadata.Source,
		tags = metadata.Tags,
		name = metadata.Version,
		creator = metadata.Creator,
		audio_path = general.AudioFilename,
		background_path = self.osu.rawOsu.Events.background,
		preview_time = tonumber(general.PreviewTime) / 1000,
		notes_count = #self.osu.protoNotes,
		duration = (self.osu.maxTime - self.osu.minTime) / 1000,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.osu.minTime / 1000,
		tempo = self.osu.primary_tempo,
		tempo_avg = self.osu.primary_tempo,
		tempo_min = self.osu.min_tempo,
		tempo_max = self.osu.max_tempo,
	})
end

function ChartDecoder:addAudio()
	local audioFileName = self.osu.rawOsu.General.AudioFilename
	if not audioFileName or audioFileName == "virtual" then
		return
	end

	local audio_layer = AbsoluteLayer()
	self.chart.layers.audio = audio_layer

	local visual = Visual()
	audio_layer.visuals.main = visual

	local visualPoint = visual:getPoint(audio_layer:getPoint(0))

	local note = Note(visualPoint, "audio")
	note.type = "sample"
	note.sounds = {{audioFileName, 1}}
	note.stream = true
	self.chart.resources:add("sound", audioFileName)

	self.chart.notes:insert(note)
end

function ChartDecoder:decodeTempos()
	local layer = self.layer
	local visual = self.visual
	for _, proto_tempo in ipairs(self.osu.protoTempos) do
		local point = layer:getPoint(proto_tempo.offset / 1000)
		point._tempo = Tempo(proto_tempo.tempo)
		visual:getPoint(point)
		-- do something with proto_tempo.signature
	end
end

function ChartDecoder:decodeVelocities()
	local layer = self.layer
	local visual = self.visual
	for _, proto_velocity in ipairs(self.osu.protoVelocities) do
		local point = layer:getPoint(proto_velocity.offset / 1000)
		local visualPoint = visual:getPoint(point)
		visualPoint._velocity = Velocity(proto_velocity.velocity)
	end
end

function ChartDecoder:decodeNotes()
	local layer = self.layer
	local chart = self.chart

	for _, proto_note in ipairs(self.osu.protoNotes) do
		local a, b = self:getNotes(proto_note)
		if a then
			chart.notes:insert(a)
		end
		if b then
			chart.notes:insert(b)
		end
	end
end

function ChartDecoder:decodeSamples()
	local layer = self.layer
	local chart = self.chart
	local visualColumns = self.visualColumns

	for _, e in ipairs(self.osu.rawOsu.Events.samples) do
		local point = layer:getPoint(e.time / 1000)
		local visualPoint = visualColumns:getPoint(point, "auto")
		local note = Note(visualPoint, "auto")
		note.type = "sample"
		note.sounds = {{e.name, e.volume / 100}}
		chart.notes:insert(note)
		self.chart.resources:add("sound", e.name)
	end
end

---@param time number
---@param column ncdk2.Column
---@param _type string
---@param sounds table?
---@param weight integer?
---@return ncdk2.Note
function ChartDecoder:getNote(time, column, _type, sounds, weight)
	local layer = self.layer
	local visualColumns = self.visualColumns
	local point = layer:getPoint(time)
	local visualPoint = visualColumns:getPoint(point, column)
	local note = Note(visualPoint, column)
	note.type = _type
	note.weight = weight or 0
	note.sounds = sounds
	return note
end

---@param proto_note osu.ProtoNote
---@return ncdk2.Note?
---@return ncdk2.Note?
function ChartDecoder:getNotes(proto_note)
	local startTime = proto_note.time and proto_note.time / 1000
	local endTime = proto_note.endTime and proto_note.endTime / 1000
	local column = "key" .. proto_note.column

	local startIsNan = startTime ~= startTime
	local endIsNan = endTime ~= endTime

	---@type {[1]: string, [2]: number}[]
	local sounds = {}
	for i, s in ipairs(proto_note.sounds) do
		sounds[i] = {s.name, s.volume / 100}
		self.chart.resources:add("sound", s.name, s.fallback_name)
	end

	if not endTime then
		if startIsNan then
			return
		end
		return self:getNote(startTime, column, "note", sounds)
	end

	if startIsNan and endIsNan then
		return
	end

	if not startIsNan and endIsNan then
		return self:getNote(startTime, column, "shade")
	end
	if startIsNan and not endIsNan then
		return self:getNote(endTime, column, "shade")
	end

	if endTime < startTime then
		return self:getNote(startTime, column, "note"), self:getNote(endTime, column, "shade")
	end

	local lnType = "hold"
	if self.mode == 2 then
		lnType = "drumroll"
	end

	local startNote = self:getNote(startTime, column, lnType, sounds, 1)
	local endNote = self:getNote(endTime, column, lnType, nil, -1)

	return startNote, endNote
end

function ChartDecoder:decodeBarlines()
	local layer = self.layer
	local chart = self.chart
	local visualColumns = self.visualColumns
	local column = "measure1"
	for _, offset in ipairs(self.osu.barlines) do
		local point = layer:getPoint(offset / 1000)
		local a = Note(visualColumns:getPoint(point, column), column)
		a.type = "shade"
		chart.notes:insert(a)
	end
end

return ChartDecoder
