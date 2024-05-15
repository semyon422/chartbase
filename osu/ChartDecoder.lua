local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Note = require("ncdk2.notes.Note")
local Velocity = require("ncdk2.visual.Velocity")
local Tempo = require("ncdk2.to.Tempo")
local AbsoluteLayer = require("ncdk2.layers.AbsoluteLayer")
local InputMode = require("ncdk.InputMode")
local Chartmeta = require("notechart.Chartmeta")
local RawOsu = require("osu.RawOsu")
local Osu = require("osu.Osu")

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

	chart.inputMode = InputMode({key = osu.keymode})

	local layer = AbsoluteLayer()
	chart.layers.main = layer
	self.layer = layer

	layer.primaryTempo = 120

	self:decodeTempos()
	self:decodeVelocities()
	self:decodeNotes()

	self:addAudio()

	chart.type = "bms"
	chart:compute()

	self:setMetadata()

	return chart
end

function ChartDecoder:setMetadata()
	local general = self.osu.rawOsu.sections.General.entries
	local metadata = self.osu.rawOsu.sections.Metadata.entries
	self.chart.chartmeta = Chartmeta({
		format = "osu",
		title = metadata.Title,
		artist = metadata.Artist,
		source = metadata.Source,
		tags = metadata.Tags,
		name = metadata.Version,
		creator = metadata.Creator,
		audio_path = general.AudioFilename,
		background_path = self.osu.rawOsu.sections.Events.background,
		preview_time = general.PreviewTime / 1000,
		notes_count = self.notes_count,
		duration = self.totalLength or 1000,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.minTime or 0,
		tempo = self.osu.primaryTempo,
		tempo_avg = self.osu.primaryTempo,
		tempo_min = self.osu.minTempo,
		tempo_max = self.osu.maxTempo,
	})
end

function ChartDecoder:addAudio()
	local audioFileName = self.osu.rawOsu.sections.General.entries.AudioFilename
	if not audioFileName or audioFileName == "virtual" then
		return
	end

	local layer = self.layer
	local point = layer:getPoint(0)
	local visualPoint = layer.visual:newPoint(point)

	local note = Note(visualPoint)
	note.noteType = "SoundNote"
	note.sounds = {{audioFileName, 1}}
	note.stream = true
	self.chart.resourceList:add("sound", audioFileName, {audioFileName})

	layer.notes:insert(note, 0)
end

function ChartDecoder:decodeTempos()
	local layer = self.layer
	for _, proto_tempo in ipairs(self.osu.protoTempos) do
		local point = layer:getPoint(proto_tempo.offset / 1000)
		point._tempo = Tempo(proto_tempo.tempo)
		-- do something with proto_tempo.signature
	end
end

function ChartDecoder:decodeVelocities()
	local layer = self.layer
	for _, proto_velocity in ipairs(self.osu.protoVelocities) do
		local point = layer:getPoint(proto_velocity.offset / 1000)
		local visualPoint = layer.visual:newPoint(point)
		visualPoint._velocity = Velocity(proto_velocity.velocity)
	end
end

function ChartDecoder:decodeNotes()
	local layer = self.layer

	for _, proto_note in ipairs(self.osu.protoNotes) do
		local a, b = self:getNotes(proto_note)
		if a then
			layer.notes:insert(a, proto_note.column)
		end
		if b then
			layer.notes:insert(b, proto_note.column)
		end
	end
end

---@param time number
---@param noteType string
---@return ncdk2.Note
function ChartDecoder:getNote(time, noteType)
	local layer = self.layer
	local point = layer:getPoint(time)
	local visualPoint = layer.visual:newPoint(point)
	local note = Note(visualPoint)
	note.noteType = noteType
	return note
end

---@param proto_note osu.ProtoNote
---@return ncdk2.Note?
---@return ncdk2.Note?
function ChartDecoder:getNotes(proto_note)
	local startTime = proto_note.time and proto_note.time / 1000
	local endTime = proto_note.endTime and proto_note.endTime / 1000

	local startIsNan = startTime ~= startTime
	local endIsNan = endTime ~= endTime

	if not endTime then
		if startIsNan then
			return
		end
		return self:getNote(startTime, "ShortNote")
	end

	if startIsNan and endIsNan then
		return
	end

	if not startIsNan and endIsNan then
		return self:getNote(startTime, "SoundNote")
	end
	if startIsNan and not endIsNan then
		return self:getNote(endTime, "SoundNote")
	end

	if endTime < startTime then
		return self:getNote(startTime, "ShortNote"), self:getNote(endTime, "SoundNote")
	end

	local lnType = "LongNoteStart"
	if self.mode == 2 then
		lnType = "DrumrollNoteStart"
	end

	local startNote = self:getNote(startTime, lnType)
	local endNote = self:getNote(endTime, "LongNoteEnd")

	endNote.startNote = startNote
	startNote.endNote = endNote

	return startNote, endNote
end

return ChartDecoder
