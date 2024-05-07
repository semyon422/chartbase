local IChartEncoder = require("notechart.IChartEncoder")
local Sph = require("sph.Sph")

---@class sph.ChartEncoder: chartbase.IChartEncoder
---@operator call: sph.ChartEncoder
local ChartEncoder = IChartEncoder + {}

local headerLines = {
	{"title", "title"},
	{"artist", "artist"},
	{"name", "name"},
	{"creator", "creator"},
	{"source", "source"},
	{"level", "level"},
	{"tags", "tags"},
	{"audio", "audio_path"},
	{"background", "background_path"},
	{"preview", "preview_time"},
	{"input", "inputmode"},
}

local noteTypeMap = {
	ShortNote = "1",
	LongNoteStart = "2",
	LongNoteEnd = "3",
	SoundNote = "4",
}

---@param a table
---@param b table
---@return boolean
local function sortNotes(a, b)
	return a.column < b.column
end

function ChartEncoder:new()
	self.notes_count = 0
	self.longNotes = {}
end

---@return table
function ChartEncoder:getMetadata()
	local chartmeta = self.chart.chartmeta

	local md = {}
	for _, d in ipairs(headerLines) do
		local k, v = d[1], chartmeta[d[2]]
		if v then
			md[k] = v
		end
	end

	return md
end

function ChartEncoder:createSoundListAndMap()
	local sounds_map = {}
	for vp, notes in pairs(self.point_notes) do
		for _, note in pairs(notes) do
			local sound = note.sounds and note.sounds[1] and note.sounds[1][1]
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

---@param _notes {[string]: ncdk2.Note}}
---@return table
function ChartEncoder:getNotes(_notes)
	local notes = {}
	for input, note in pairs(_notes) do
		local column = self.inputMap[input]
		local t = noteTypeMap[note.noteType]
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

---@param a table
---@param b table
---@return boolean
local function sortSound(a, b)
	if a.column == b.column then
		return a.sound < b.sound
	end
	return a.column < b.column
end

---@param _notes {[string]: ncdk2.Note}}
---@return table
---@return table
function ChartEncoder:getSounds(_notes)
	local sounds_map = self.sounds_map

	local notes = {}
	for input, note in pairs(_notes) do
		local column = self.inputMap[input]
		local nds = note.sounds and note.sounds[1]
		local nsound = nds and nds[1]
		local nvolume = nds and nds[2]
		table.insert(notes, {
			column = column or math.huge,
			sound = sounds_map[nsound] or 0,
			volume = nvolume or 1,
		})
	end
	table.sort(notes, sortSound)

	local sounds = {}
	local volume = {}
	for i, note in ipairs(notes) do
		sounds[i] = note.sound
		volume[i] = note.volume
	end
	for i = #sounds, 1, -1 do
		if sounds[i] == 0 then
			sounds[i] = nil
		else
			break
		end
	end
	for i = #volume, 1, -1 do
		if volume[i] == 1 then
			volume[i] = nil
		else
			break
		end
	end

	return sounds, volume
end

---@param charts ncdk2.Chart[]
---@return string
function ChartEncoder:encode(charts)
	local chart = charts[1]
	self.chart = chart

	local sph = Sph()
	local sphLines = sph.sphLines

	sph.metadata = self:getMetadata()

	local inputMode = chart.inputMode
	self.inputMap = inputMode:getInputMap()

	local layer = chart.layers.main
	self.layer = layer

	---@type {[ncdk2.VisualPoint]: {[string]: ncdk2.Note}}
	local point_notes = {}
	self.point_notes = point_notes

	for _, vp in ipairs(layer.visualPoints) do
		point_notes[vp] = {}
	end

	for inputType, r in pairs(layer.notes.data) do
		for inputIndex, notes in pairs(r) do
			for _, note in ipairs(notes) do
				local key = inputType .. inputIndex
				local vp = note.visualPoint
				local nds = point_notes[vp]
				if nds[key] then
					error("can not assign NoteData, input already used: " .. key)
				end
				nds[key] = note
			end
		end
	end

	self:createSoundListAndMap()
	sph.sounds = self.sounds

	---@type ncdk.Fraction
	local prev_time
	for _, vp in ipairs(layer.visualPoints) do
		local t = vp.point
		---@cast t -ncdk2.Point, +ncdk2.IntervalPoint

		local line = {}

		if prev_time == t.time then
			line.visual = true
		end
		prev_time = t.time

		if not line.visual then
			if t._interval then
				line.offset = t._interval.offset
			end
			if t._measure then
				line.measure = t._measure.start
			end
		end

		line.globalTime = t.time
		line.notes = self:getNotes(point_notes[vp])
		line.sounds, line.volume = self:getSounds(point_notes[vp])
		line.comment = t.comment
		if vp._expand then
			line.expand = vp._expand.duration
		end
		if vp._velocity then
			line.velocity = {
				vp._velocity.currentSpeed,
				vp._velocity.localSpeed,
				vp._velocity.globalSpeed,
			}
		end
		table.insert(sphLines.protoLines, line)
	end

	return sph:encode()
end

return ChartEncoder