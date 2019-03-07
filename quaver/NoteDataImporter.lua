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

NoteDataImporter.HitSounds = {
	Normal = "sound-hit.wav",
	Whistle = "sound-hitwhistle.wav",
	Finish = "sound-hitfinish.wav",
	Clap = "sound-hitclap.wav"
}

NoteDataImporter.init = function(self)
	self.inputIndex = self.hitObject.Lane
	self.startTime = self.hitObject.StartTime
	self.endTime = self.hitObject.EndTime
	
	self.sounds = {}
	self.hitSound = self.hitObject.HitSound
	if not self.hitSound then
		self.sounds[1] = self.HitSounds.Normal
	else
		local soundsTable = self.hitSound:split(",")
		for _, sound in ipairs(soundsTable) do
			sound = sound:trim()
			self.sounds[#self.sounds + 1] = NoteDataImporter.HitSounds[sound] or sound
		end
	end
	
	for _, sound in ipairs(self.sounds) do
		self.noteChart:addResource("sound", sound)
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

NoteDataImporter.getNoteData = osuNoteDataImporter.getNoteData

return NoteDataImporter
