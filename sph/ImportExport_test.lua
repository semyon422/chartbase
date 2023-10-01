local NoteChartImporter = require("sph.NoteChartImporter")
local NoteChartExporter = require("sph.NoteChartExporter")

local test = {}

function test.impexp_1(t)
	local nci = NoteChartImporter()
	local nce = NoteChartExporter()

	local chart = [[
# metadata
title Title
artist Artist
audio audio.mp3
input 4key

# notes
0100 +1/2
1000 =0.01
0100 +1/2
1000
0100 +1/2 x1.1 #1/2
0004 v e0.5
1000 x1
0100 +1/2
0010
-
-
- =1.01
]]

	nci.content = chart
	nci:import()

	nce.noteChart = nci.noteCharts[1]
	local expected = nce:export()

	t:eq(expected, chart)
end

return test
