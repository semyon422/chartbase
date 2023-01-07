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

NoteChartExporter.getLine = function(self, timePoint, columns, inputMap)
	local notes = {}
	for i = 1, columns do
		notes[i] = "0"
	end
	for _, noteData in ipairs(timePoint.noteDatas) do

	end
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
	local columns = inputMode:getColumns()
	local inputMap = inputMode:getInputMap()

	local ld = noteChart:getLayerData(1)

	local timePointList = ld.timePointList
	local timePointIndex = 1
	local timePoint = timePointList[1]

	local expandOffset = 0

	local currentTime = timePoint.time
	while timePoint do
		if timePoint._intervalData then
			currentTime = timePoint.time
		end

		local beatOffset = currentTime:floor()

		local targetTime = Fraction:new(beatOffset + 1)
		if timePoint.time < targetTime then
			targetTime = timePoint.time
		end
		local isAtTimePoint = timePoint.time == targetTime

		if isAtTimePoint then
			if timePoint.visualSide == 0 then
				expandOffset = 0
				print("time", timePoint.time - timePoint.time:floor())
			else
				if timePoint._expandData then
					expandOffset = expandOffset + timePoint._expandData.duration
					print(".time", expandOffset)
				else
					print(".time")
				end
			end

			timePointIndex = timePointIndex + 1
			timePoint = timePointList[timePointIndex]
		else
			print("t time", 0)
		end
		currentTime = targetTime
	end

	return table.concat(lines, "\n")
end

return NoteChartExporter
