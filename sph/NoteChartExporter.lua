local class = require("class")
local Fraction = require("ncdk.Fraction")

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
	{"bpm", "bpm"},
	{"preview", "previewTime"},
	{"input", "inputMode"},
}

local noteTypeMap = {
	ShortNote = 1,
	LongNoteStart = 2,
	LongNoteEnd = 3,
	SoundNote = 4,
}

---@param t table
---@return boolean
function NoteChartExporter:checkEmpty(t)
	return
		not t._intervalData and
		not t._velocityData and
		not t._expandData and
		not t._measureData and
		not (t.noteDatas and next(t.noteDatas))
end

---@param timePoint table
---@return string?
function NoteChartExporter:getLine(timePoint)
	if self:checkEmpty(timePoint) then
		return
	end
	local notes = {}
	for i = 1, self.columns do
		notes[i] = "0"
	end
	if not timePoint.noteDatas then
		return table.concat(notes)
	end
	for input, noteData in pairs(timePoint.noteDatas) do
		local column = self.inputMap[input]
		local t = noteTypeMap[noteData.noteType]
		if column and t then
			notes[column] = t
		end
	end
	return table.concat(notes)
end

---@param n number|ncdk.Fraction
---@return string
local function formatNumber(n)
	if n == math.huge then
		return "1/0"
	end
	if type(n) == "number" then
		n = Fraction(n, 192, false)
	end
	if n[2] == 1 then
		return n[1]
	end
	return n[1] .. "/" .. n[2]
end

---@return string
function NoteChartExporter:export()
	local noteChart = self.noteChart
	local lines = {}

	local metaData = noteChart.metaData
	for _, d in ipairs(headerLines) do
		table.insert(lines, ("%s=%s"):format(d[1], metaData[d[2]]))
	end
	table.insert(lines, "")

	local inputMode = noteChart.inputMode
	self.columns = inputMode:getColumns()
	self.inputMap = inputMode:getInputMap()

	local ld = noteChart:getLayerData(1)
	ld:assignNoteDatas()

	local timePointList = ld.timePointList
	local timePointIndex = 1
	local timePoint = timePointList[1]

	local beatOffset = 0
	local prevIntervalData
	for _, t in ipairs(timePointList) do
		if t._intervalData and prevIntervalData then
			beatOffset = beatOffset + prevIntervalData.beats
		end
		prevIntervalData = t._intervalData or prevIntervalData
		t.globalTime = t.time + beatOffset
	end

	local visualSideStarted = false
	local dataStarted = false

	local currentTime = timePoint.globalTime
	local prevTime = nil
	while timePoint do
		local targetTime = Fraction(currentTime:floor() + 1)
		if timePoint.globalTime < targetTime then
			targetTime = timePoint.globalTime
		end
		local isAtTimePoint = timePoint.globalTime == targetTime

		if isAtTimePoint then
			local line = self:getLine(timePoint)

			if timePoint.globalTime ~= prevTime then
				visualSideStarted = nil
				prevTime = timePoint.globalTime
			end

			local dt = timePoint.globalTime % 1
			if line then
				dataStarted = true

				if not visualSideStarted then
					visualSideStarted = true
					if dt[1] ~= 0 then
						line = line .. "+" .. formatNumber(dt)
					end
				else
					line = line .. "."
					if timePoint._expandData then
						line = line .. "e" .. formatNumber(timePoint._expandData.duration)
					end
				end
				if timePoint._intervalData then
					line = line .. "=" .. timePoint._intervalData.timePoint.absoluteTime
				end
				if timePoint._measureData then
					local n = timePoint._measureData.start
					line = line .. "#" .. (n[1] ~= 0 and formatNumber(n) or "")
				end
				if timePoint._velocityData then
					line = line .. "x" .. formatNumber(timePoint._velocityData.currentSpeed)
				end
			end
			if dataStarted then
				if line then
					table.insert(lines, line)
				elseif dt[1] == 0 and not visualSideStarted then
					table.insert(lines, "-")
					visualSideStarted = true
				end
			end

			timePointIndex = timePointIndex + 1
			timePoint = timePointList[timePointIndex]
		elseif dataStarted then
			table.insert(lines, "-")
		end
		currentTime = targetTime
	end

	for i = #lines, 1, -1 do
		if lines[i] == "-" then
			lines[i] = nil
		else
			break
		end
	end

	return table.concat(lines, "\n")
end

return NoteChartExporter
