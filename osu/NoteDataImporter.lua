local ncdk = require("ncdk")

local NoteDataImporter = {}

local NoteDataImporter_metatable = {}
NoteDataImporter_metatable.__index = NoteDataImporter

NoteDataImporter.new = function(self, note)
	local noteDataImporter = note or {}
	
	setmetatable(noteDataImporter, NoteDataImporter_metatable)
	
	return noteDataImporter
end

NoteDataImporter.inputType = "key"

NoteDataImporter.init = function(self)
	for i, soundData in ipairs(self.sounds) do
		soundData[2] = soundData[2] / 100
		self.noteChart:addResource("sound", soundData[1], {soundData[1], self.fallbackSounds[i][1]})
	end
	
	if not self.noteChartImporter.specialStyle then
		self.inputIndex = self.key
	elseif self.key == 1 then
		self.inputType = "scratch"
		self.inputIndex = self.key
	else
		self.inputIndex = self.key - 1
	end
	
	local firstTime = math.min(self.endTime or self.startTime, self.startTime)
	if not self.noteChartImporter.minTime or firstTime < self.noteChartImporter.minTime then
		self.noteChartImporter.minTime = firstTime
	end
	
	local lastTime = math.max(self.endTime or self.startTime, self.startTime)
	if not self.noteChartImporter.maxTime or lastTime > self.noteChartImporter.maxTime then
		self.noteChartImporter.maxTime = lastTime
	end
end

NoteDataImporter.initEvent = function(self)
	self.sounds = {}
	if self.sound and self.sound ~= "" then
		self.sounds[1] = {self.sound, self.volume / 100}
		self.noteChart:addResource("sound", self.sound, {self.sound})
	end
	
	self.inputType = "auto"
	self.inputIndex = 0
end

NoteDataImporter.getNoteData = function(self)
	local startNoteData, endNoteData
	
	local startTimePoint = self.noteChartImporter.foregroundLayerData:getTimePoint(self.startTime / 1000)
	
	startNoteData = ncdk.NoteData:new(startTimePoint)
	startNoteData.inputType = self.inputType
	startNoteData.inputIndex = self.inputIndex
	startNoteData.sounds = self.sounds
	
	if self.inputType == "auto" then
		startNoteData.noteType ="SoundNote"
	elseif not self.endTime then
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
		
		if self.endTime < self.startTime then
			startNoteData.noteType = "ShortNote"
			endNoteData.noteType = "SoundNote"
		end
	end
	
	return startNoteData, endNoteData
end

return NoteDataImporter
