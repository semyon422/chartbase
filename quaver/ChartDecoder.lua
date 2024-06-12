local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Note = require("ncdk2.notes.Note")
local Velocity = require("ncdk2.visual.Velocity")
local Tempo = require("ncdk2.to.Tempo")
local AbsoluteLayer = require("ncdk2.layers.AbsoluteLayer")
local InputMode = require("ncdk.InputMode")
local Barlines = require("osu.Barlines")
local PrimaryTempo = require("osu.PrimaryTempo")
local Chartmeta = require("notechart.Chartmeta")
local tinyyaml = require("tinyyaml")

---@class quaver.ChartDecoder: chartbase.IChartDecoder
---@operator call: quaver.ChartDecoder
local ChartDecoder = IChartDecoder + {}

function ChartDecoder:new()
	self.notes_count = 0
end

---@param s string
---@return ncdk2.Chart[]
function ChartDecoder:decode(s)
	local qua = tinyyaml.parse(s:gsub("\r\n", "\n"))
	local chart = self:decodeQua(qua)
	return {chart}
end

---@param qua table
---@return ncdk2.Chart[]
function ChartDecoder:decodeQua(qua)
	self.qua = qua

	local chart = Chart()
	self.chart = chart

	local layer = AbsoluteLayer()
	chart.layers.main = layer
	self.layer = layer

	layer.visual.primaryTempo = 120

	self:decodeTempos()
	self:decodeVelocities()
	self:decodeNotes()

	local tempo_points = self:getTempoPoints()
	self:decodeBarlines(tempo_points)
	self.primary_tempo, self.min_tempo, self.max_tempo = PrimaryTempo:compute(tempo_points, self.maxTime)

	self:addAudio()

	self.columns = tonumber(qua.Mode:sub(-1, -1))
	chart.inputMode = InputMode({key = self.columns})
	chart.type = "quaver"

	chart:compute()

	self:setMetadata()

	return chart
end

function ChartDecoder:setMetadata()
	local qua = self.qua
	self.chart.chartmeta = Chartmeta({
		format = "qua",
		title = tostring(qua["Title"]),  -- yaml can parse it as number
		artist = tostring(qua["Artist"]),
		source = tostring(qua["Source"]),
		tags = tostring(qua["Tags"]),
		name = tostring(qua["DifficultyName"]),
		creator = tostring(qua["Creator"]),
		audio_path = tostring(qua["AudioFile"]),
		background_path = tostring(qua["BackgroundFile"]),
		preview_time = (qua["SongPreviewTime"] or 0) / 1000,
		notes_count = self.notes_count,
		duration = self.maxTime - self.minTime,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.minTime / 1000,
		tempo = self.primary_tempo,
		tempo_avg = self.primary_tempo,
		tempo_min = self.min_tempo,
		tempo_max = self.max_tempo,
	})
end

function ChartDecoder:addAudio()
	local audioFileName = self.qua.AudioFile
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

	layer.notes:insert(note, "audio")
end

function ChartDecoder:decodeTempos()
	local layer = self.layer
	for _, tp in ipairs(self.qua.TimingPoints) do
		if tp.Bpm then
			local point = layer:getPoint(tp.StartTime / 1000)
			point._tempo = Tempo(tp.Bpm)
			-- do something with tp.Singature
		end
	end
end

function ChartDecoder:decodeVelocities()
	local layer = self.layer
	for _, sv in ipairs(self.qua.SliderVelocities) do
		local point = layer:getPoint(sv.StartTime / 1000)
		local visualPoint = layer.visual:newPoint(point)
		visualPoint._velocity = Velocity(sv.Multiplier)
	end
end

function ChartDecoder:decodeNotes()
	local layer = self.layer

	self.maxTime = 0
	self.minTime = math.huge
	for _, obj in ipairs(self.qua.HitObjects) do
		local a, b = self:getNotes(obj)
		local column = "key" .. obj.Lane
		if a then
			layer.notes:insert(a, column)
		end
		if b then
			layer.notes:insert(b, column)
		end
	end
end

---@param time number
---@param noteType string
---@param sounds table?
---@return ncdk2.Note
function ChartDecoder:getNote(time, noteType, sounds)
	local layer = self.layer
	local point = layer:getPoint(time)
	local visualPoint = layer.visual:newPoint(point)
	local note = Note(visualPoint)
	note.noteType = noteType
	note.sounds = sounds
	return note
end

---@param obj table
---@return ncdk2.Note?
---@return ncdk2.Note?
function ChartDecoder:getNotes(obj)
	local startTime = obj.StartTime and obj.StartTime / 1000
	local endTime = obj.EndTime and obj.EndTime / 1000

	if startTime then
		self.maxTime = math.max(self.maxTime, startTime)
		self.minTime = math.min(self.minTime, startTime)
	end
	if endTime then
		self.maxTime = math.max(self.maxTime, endTime)
		self.minTime = math.min(self.minTime, endTime)
	end

	---@type {[1]: string, [2]: number}[]
	local sounds = {}  -- TODO: fix hitsounds/keysounds

	if not endTime then
		return self:getNote(startTime, "ShortNote", sounds)
	end

	if endTime < startTime then
		return self:getNote(startTime, "ShortNote"), self:getNote(endTime, "SoundNote")
	end

	local startNote = self:getNote(startTime, "LongNoteStart", sounds)
	local endNote = self:getNote(endTime, "LongNoteEnd")

	endNote.startNote = startNote
	startNote.endNote = endNote

	return startNote, endNote
end

---@return osu.FilteredPoint[]
function ChartDecoder:getTempoPoints()
	---@type osu.FilteredPoint[]
	local tempo_points = {}

	for _, tp in ipairs(self.qua.TimingPoints) do
		if tp.Bpm then
			table.insert(tempo_points, {
				offset = tp.StartTime,
				beatLength = 60000 / tp.Bpm,
				signature = tp.Singature or 4,
			})
		end
	end

	return tempo_points
end

function ChartDecoder:decodeBarlines(tempo_points)
	local barlines = Barlines:generate(tempo_points, self.maxTime)

	local layer = self.layer
	for _, offset in ipairs(barlines) do
		local point = layer:getPoint(offset / 1000)

		local a = Note(layer.visual:newPoint(point))
		a.noteType = "LineNoteStart"
		layer.notes:insert(a, "measure1")

		local b = Note(layer.visual:newPoint(point))
		b.noteType = "LineNoteEnd"
		layer.notes:insert(b, "measure1")

		a.endNote = b
		b.startNote = a
	end
end

return ChartDecoder