local ncdk = require("ncdk")
local osuNoteDataImporter = require("osu.NoteDataImporter")

local NoteDataImporter = {}

local NoteDataImporter_metatable = {}
NoteDataImporter_metatable.__index = NoteDataImporter

NoteDataImporter.new = function(self)
	local noteDataImporter = {}
	
	setmetatable(noteDataImporter, NoteDataImporter_metatable)
	
	return noteDataImporter
end

NoteDataImporter.inputType = "key"

NoteDataImporter.init = function(self)
	self.inputIndex = self.hitObject.Lane
	self.startTime = self.hitObject.StartTime
	self.endTime = self.hitObject.EndTime
	
	local lastTime = self.endTime or self.startTime
	if lastTime > self.noteChartImporter.totalLength then
		self.noteChartImporter.totalLength = lastTime
	end
end

NoteDataImporter.getNoteData = osuNoteDataImporter.getNoteData

return NoteDataImporter
