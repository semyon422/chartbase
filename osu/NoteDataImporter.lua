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
	self.lineTable = self.line:split(",")
	self.additionLineTable = self.lineTable[6]:split(":")
	
	self.x = tonumber(self.lineTable[1])
	self.y = tonumber(self.lineTable[2])
	self.startTime = tonumber(self.lineTable[3])
	self.type = tonumber(self.lineTable[4])
	self.hitSoundBitmap = tonumber(self.lineTable[5])
	if bit.band(self.type, 128) == 128 then
		self.endTime = tonumber(self.additionLineTable[1])
		table.remove(self.additionLineTable, 1)
	end
	self.additionSampleSetId = tonumber(self.additionLineTable[1])
	self.additionAdditionalSampleSetId = tonumber(self.additionLineTable[2])
	self.additionCustomSampleSetIndex = tonumber(self.additionLineTable[3])
	self.additionHitSoundVolume = tonumber(self.additionLineTable[4])
	self.additionCustomHitSound = self.additionLineTable[5]
	
	self.sounds = {}
	if self.additionCustomHitSound and self.additionCustomHitSound ~= "" then
		self.sounds[1] = self.additionCustomHitSound
		self.noteChart:addResource("sound", self.additionCustomHitSound)
	end
	
	local keymode = self.noteChartImporter.metaData.CircleSize
	local interval = 512 / keymode
	for currentInputIndex = 1, keymode do
		if self.x >= interval * (currentInputIndex - 1) and self.x < currentInputIndex * interval then
			self.inputIndex = currentInputIndex
			break
		end
	end
	
	local lastTime = self.endTime or self.startTime
	if lastTime > self.noteChartImporter.totalLength then
		self.noteChartImporter.totalLength = lastTime
	end
end

NoteDataImporter.initEvent = function(self)
	self.lineTable = self.line:split(",")
	
	self.startTime = tonumber(self.lineTable[2])
	self.hitSound = self.lineTable[4]:match("\"(.+)\"")
	self.volume = tonumber(self.lineTable[5])
	
	self.sounds = {}
	if self.hitSound and self.hitSound ~= "" then
		self.sounds[1] = self.hitSound
		self.noteChart:addResource("sound", self.hitSound)
	end
	
	self.inputType = "auto"
	self.inputIndex = 0
	
	if self.startTime > self.noteChartImporter.totalLength then
		self.noteChartImporter.totalLength = self.startTime
	end
end

NoteDataImporter.getNoteData = function(self)
	local startNoteData, endNoteData
	
	local startTimePoint = self.noteChartImporter.foregroundLayerData:getTimePoint(self.startTime / 1000)
	
	startNoteData = ncdk.NoteData:new(startTimePoint)
	startNoteData.inputType = self.inputType
	startNoteData.inputIndex = self.inputIndex
	startNoteData.sounds = self.sounds
	
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
