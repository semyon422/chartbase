local ncdk = require("ncdk")

local NoteDataExporter = {}

local NoteDataExporter_metatable = {}
NoteDataExporter_metatable.__index = NoteDataExporter

NoteDataExporter.new = function(self)
	local noteDataExporter = {}
	
	setmetatable(noteDataExporter, NoteDataExporter_metatable)
	
	return noteDataExporter
end

local hitObjectString = "%s,%s,%s,%s,0,%s"
local shortAddition = "0:0:0:0:%s"
local longAddition = "%s:0:0:0:0:%s"
NoteDataExporter.getHitObject = function(self)
	local noteData = self.noteData
	
	local soundData = noteData.sounds and noteData.sounds[1]
	local hitSound = ""
	if soundData then
		hitSound = soundData[1]
	end
	
	if not self.mappings[noteData.inputType] then
		return
	end
	
	local key = self.mappings[noteData.inputType][noteData.inputIndex]
	local keymode = self.mappings.keymode
	if not key then
		key = noteData.inputIndex
	end
	
	local x = 512 / keymode * (key - 0.5)
	local y = 192
	local startTime = math.floor(noteData.timePoint.absoluteTime * 1000)
	local endTime
	local noteType
	local addition
	if noteData.noteType == "LongNoteStart" then
		endTime = math.floor(noteData.endNoteData.timePoint.absoluteTime * 1000)
		noteType = 128
		addition = longAddition:format(endTime, hitSound)
	else
		noteType = 1
		addition = shortAddition:format(hitSound)
	end
	
	return hitObjectString:format(x, y, startTime, noteType, addition)
end

local eventSampleString = "5,%s,0,\"%s\",100"
NoteDataExporter.getEventSample = function(self)
	local noteData = self.noteData
	
	if noteData.noteType ~= "SoundNote" then
		return
	end
	
	local soundData = noteData.sounds and noteData.sounds[1]
	local hitSound = ""
	if soundData then
		hitSound = soundData[1]
	end
	local startTime = math.floor(noteData.timePoint.absoluteTime * 1000)
	
	return eventSampleString:format(startTime, hitSound)
end

return NoteDataExporter
