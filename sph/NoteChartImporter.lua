local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}
	
	setmetatable(noteChartImporter, NoteChartImporter_metatable)
	
	return noteChartImporter
end

NoteChartImporter.import = function(self, noteChartString)
	local directoryPath, fileName = self.path:match("^(.+)/(.-)%.sph$")
	self.noteChart = dofile(directoryPath .. "/" .. fileName .. ".lua")(directoryPath)
	return self.noteChart
end

return NoteChartImporter
