local ncdk = require("ncdk")

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
	self.inputType = "key"
	self.inputIndex = self.hitObject.Lane
	self.startTime = self.hitObject.StartTime
	self.endTime = self.hitObject.EndTime
	
	local lastTime = self.endTime or self.startTime
	if lastTime > self.noteChartImporter.totalLength then
		self.noteChartImporter.totalLength = lastTime
	end
end

NoteDataImporter.getNoteData = function(self)
	local startNoteData, endNoteData
	
	local startTimePoint = self.noteChartImporter.foregroundLayerData:getTimePoint(self.startTime / 1000)
	
	startNoteData = ncdk.NoteData:new(startTimePoint)
	startNoteData.inputType = self.inputType
	startNoteData.inputIndex = self.inputIndex
	
	if not self.endTime then
		startNoteData.noteType = "ShortNote"
	else
		startNoteData.noteType = "LongNoteStart"
		
		local endTimePoint = self.noteChartImporter.foregroundLayerData:getTimePoint(self.endTime / 1000)
		
		endNoteData = ncdk.NoteData:new(endTimePoint)
		endNoteData.inputType = self.inputType
		endNoteData.inputIndex = self.inputIndex
	
		endNoteData.noteType = "LongNoteEnd"
		
		endNoteData.startNoteData = startNoteData
		startNoteData.endNoteData = endNoteData
	end
	
	return startNoteData, endNoteData
end

return NoteDataImporter
