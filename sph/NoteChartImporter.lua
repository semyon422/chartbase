local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self)
	local directoryPath, fileName = self.path:match("^(.+)/(.-)%.sph$")

	local noteCharts = dofile(directoryPath .. "/" .. fileName .. ".lua")(directoryPath, self.path)

	print(#noteCharts)
	self.noteCharts = noteCharts
end

return NoteChartImporter
