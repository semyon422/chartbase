local class = require("class")
local Sph = require("sph.Sph")

---@class sph.NoteChartExporter
---@operator call: sph.NoteChartExporter
local NoteChartExporter = class()

local headerLines = {
	{"title", "title"},
	{"artist", "artist"},
	{"name", "name"},
	{"creator", "creator"},
	{"source", "source"},
	{"level", "level"},
	{"tags", "tags"},
	{"audio", "audioPath"},
	{"background", "stagePath"},
	{"preview", "previewTime"},
	{"input", "inputMode"},
}

local noteTypeMap = {
	ShortNote = 1,
	LongNoteStart = 2,
	LongNoteEnd = 3,
	SoundNote = 4,
}

function NoteChartExporter:new()
	self.sph = Sph()
end

local function sortNotes(a, b)
	return a.column < b.column
end

---@param timePoint ncdk.IntervalTimePoint
---@return table
function NoteChartExporter:getNotes(timePoint)
	local notes = {}
	for input, noteData in pairs(timePoint.noteDatas) do
		local column = self.inputMap[input]
		local t = noteTypeMap[noteData.noteType]
		if column and t then
			table.insert(notes, {
				column = column,
				type = t,
			})
		end
	end
	table.sort(notes, sortNotes)
	return notes
end

local function sortSound(a, b)
	if a.column == b.column then
		return a.sound < b.sound
	end
	return a.column < b.column
end

---@param timePoint ncdk.IntervalTimePoint
---@return table
function NoteChartExporter:getSounds(timePoint)
	local sounds_map = self.sounds_map

	local notes = {}
	for input, noteData in pairs(timePoint.noteDatas) do
		local column = self.inputMap[input]
		local nsound = noteData.sounds and noteData.sounds[1] and noteData.sounds[1][1]
		table.insert(notes, {
			column = column or math.huge,
			sound = sounds_map[nsound] or 0,
		})
	end
	table.sort(notes, sortSound)
	local sounds = {}
	for i, note in ipairs(notes) do
		sounds[i] = note.sound
	end
	for i = #sounds, 1, -1 do
		if sounds[i] == 0 then
			sounds[i] = nil
		else
			break
		end
	end
	return sounds
end

---@return table
function NoteChartExporter:getMetadata()
	local metaData = self.noteChart.metaData

	local md = {}
	for _, d in ipairs(headerLines) do
		local k, v = d[1], metaData[d[2]]
		if v then
			md[k] = v
		end
	end

	return md
end

function NoteChartExporter:createSoundListAndMap()
	local sounds_map = {}
	for _, t in ipairs(self.layerData.timePointList) do
		for _, noteData in pairs(t.noteDatas) do
			local sound = noteData.sounds and noteData.sounds[1] and noteData.sounds[1][1]
			if sound then
				sounds_map[sound] = true
			end
		end
	end
	local sounds = {}
	for sound in pairs(sounds_map) do
		table.insert(sounds, sound)
	end
	table.sort(sounds)
	for i, sound in ipairs(sounds) do
		sounds_map[sound] = i
	end
	self.sounds = sounds
	self.sounds_map = sounds_map
end

---@return string
function NoteChartExporter:export()
	local noteChart = self.noteChart

	local sph = self.sph
	local sphLines = sph.sphLines

	sph.metadata = self:getMetadata()

	local inputMode = noteChart.inputMode
	sphLines.columns = inputMode:getColumns()
	self.inputMap = inputMode:getInputMap()

	local ld = noteChart:getLayerData(1)
	ld:assignNoteDatas()
	self.layerData = ld

	self:createSoundListAndMap()
	sph.sounds = self.sounds

	for _, t in ipairs(ld.timePointList) do
		if t._intervalData then
			table.insert(sphLines.intervals, {
				offset = t.absoluteTime,
				beats = t._intervalData.beats,
				start = t._intervalData.start,
			})
		end

		local line = {}
		line.time = t.time
		line.visualSide = t.visualSide
		line.notes = self:getNotes(t)
		line.sounds = self:getSounds(t)
		line.intervalIndex = math.max(#sphLines.intervals, 1)
		line.intervalSet = t._intervalData ~= nil
		if t._expandData then
			line.expand = t._expandData.duration
		end
		if t._velocityData then
			line.velocity = t._velocityData.currentSpeed
		end
		if t._measureData then
			line.measure = t._measureData.start
		end
		table.insert(sphLines.lines, line)
	end

	return sph:encode()
end

return NoteChartExporter
