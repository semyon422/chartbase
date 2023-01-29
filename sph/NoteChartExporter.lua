local Fraction = require("ncdk.Fraction")

local NoteChartExporter = {}

local NoteChartExporter_metatable = {}
NoteChartExporter_metatable.__index = NoteChartExporter

NoteChartExporter.new = function(self)
	local noteChartExporter = {}

	setmetatable(noteChartExporter, NoteChartExporter_metatable)

	return noteChartExporter
end

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

NoteChartExporter.checkEmpty = function(self, t)
	return
		not t._intervalData and
		not t._velocityData and
		not t._expandData and
		not (t.noteDatas and next(t.noteDatas))
end

NoteChartExporter.getLine = function(self, timePoint)
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

local function formatNumber(n)
	if n == math.huge then
		return "1/0"
	end
	if type(n) == "number" then
		n = Fraction:new(n, 192, false)
	end
	if n[2] == 1 then
		return n[1]
	end
	return n[1] .. "/" .. n[2]
end

NoteChartExporter.export = function(self)
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

	local expandOffset = 0
	local dataStarted = false

	local currentTime = timePoint.globalTime
	while timePoint do
		local targetTime = Fraction:new(currentTime:floor() + 1)
		if timePoint.globalTime < targetTime then
			targetTime = timePoint.globalTime
		end
		local isAtTimePoint = timePoint.globalTime == targetTime

		if isAtTimePoint then
			local line = self:getLine(timePoint)

			local dt = timePoint.globalTime % 1
			if line then
				dataStarted = true
				if timePoint.visualSide == 0 then
					expandOffset = 0
					if dt[1] ~= 0 then
						line = line .. "+" .. formatNumber(dt)
					end
					if timePoint._intervalData then
						line = line .. "=" .. timePoint._intervalData.timePoint.absoluteTime
					end
				else
					line = "." .. line
					if timePoint._expandData then
						expandOffset = expandOffset + timePoint._expandData.duration
						if expandOffset % 1 ~= 0 or expandOffset == 0 then
							line = line .. "+" .. formatNumber(expandOffset)
						end
					end
				end
				if timePoint._velocityData then
					line = line .. "x" .. formatNumber(timePoint._velocityData.currentSpeed)
				end
			end
			if dataStarted and (line or dt[0] == 0) then
				table.insert(lines, line or "-")
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
