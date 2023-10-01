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
	return notes
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
