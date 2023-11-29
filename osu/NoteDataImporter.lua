local class = require("class")
local ncdk = require("ncdk")

---@class osu.NoteDataImporter
---@operator call: osu.NoteDataImporter
local NoteDataImporter = class()

NoteDataImporter.inputType = "key"

function NoteDataImporter:init()
	for i, soundData in ipairs(self.sounds) do
		soundData[2] = soundData[2] / 100
		self.noteChart:addResource("sound", soundData[1], {soundData[1], self.fallbackSounds[i][1]})
	end

	self.inputIndex = self.key

	local firstTime = math.min(self.endTime or self.startTime, self.startTime)
	if firstTime == firstTime then
		if not self.noteChartImporter.minTime or firstTime < self.noteChartImporter.minTime then
			self.noteChartImporter.minTime = firstTime
		end
	end

	local lastTime = math.max(self.endTime or self.startTime, self.startTime)
	if lastTime == lastTime then
		if not self.noteChartImporter.maxTime or lastTime > self.noteChartImporter.maxTime then
			self.noteChartImporter.maxTime = math.min(lastTime, 3600 * 2 * 1000)
		end
	end
end

function NoteDataImporter:initEvent()
	self.sounds = {}
	if self.sound and self.sound ~= "" then
		self.sounds[1] = {self.sound, self.volume / 100}
		self.noteChart:addResource("sound", self.sound, {self.sound})
	end
	self.keysound = true

	self.inputType = "auto"
	self.inputIndex = 0
end

function NoteDataImporter:getNote(time, noteType)
	local startTimePoint = self.noteChartImporter.foregroundLayerData:getTimePoint(time / 1000)

	local startNoteData = ncdk.NoteData(startTimePoint)
	startNoteData.inputType = self.inputType
	startNoteData.inputIndex = self.inputIndex
	startNoteData.sounds = self.sounds
	startNoteData.keysound = self.keysound
	startNoteData.noteType = noteType

	return startNoteData
end

local function noSounds(noteData)
	noteData.sounds = nil
	return noteData
end

---@return ncdk.NoteData?
---@return ncdk.NoteData?
function NoteDataImporter:getNoteData()
	local startTime = self.startTime
	local endTime = self.endTime

	if self.inputType == "auto" then
		return self:getNote(startTime, "SoundNote")
	end

	if not endTime then
		if startTime ~= startTime then
			return
		end
		return self:getNote(startTime, "ShortNote")
	end

	local startIsNan = startTime ~= startTime
	local endIsNan = endTime ~= endTime

	if startIsNan and endIsNan then
		return
	end

	if not startIsNan and endIsNan then
		return noSounds(self:getNote(startTime, "SoundNote"))
	end
	if startIsNan and not endIsNan then
		return noSounds(self:getNote(endTime, "SoundNote"))
	end

	if endTime < startTime then
		return self:getNote(startTime, "ShortNote"), noSounds(self:getNote(endTime, "SoundNote"))
	end

	local lnType = "LongNoteStart"
	if self.mode == 2 then
		lnType = "DrumrollNoteStart"
	end

	local startNoteData = self:getNote(startTime, lnType)
	local endNoteData = self:getNote(endTime, "LongNoteEnd")

	endNoteData.sounds = nil

	endNoteData.startNoteData = startNoteData
	startNoteData.endNoteData = endNoteData

	return startNoteData, endNoteData
end

return NoteDataImporter
