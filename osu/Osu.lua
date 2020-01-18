local Osu = {}

local Osu_metatable = {}
Osu_metatable.__index = Osu

Osu.keymode = 4
Osu.mode = 0

Osu.new = function(self)
	local osu = {}
	
	osu.metadata = {}
	osu.events = {}
	osu.timingPoints = {}
	osu.hitObjects = {}
	
	setmetatable(osu, Osu_metatable)
	
	return osu
end

Osu.import = function(self, noteChartString)
	self.noteChartString = noteChartString
	self:setDefaultMetadata()
	self:process()
	self:checkMissing()
	self:postProcess()
end

Osu.process = function(self)
	for _, line in ipairs(self.noteChartString:split("\n")) do
		self:processLine(line)
	end
end

Osu.postProcess = function(self)
	local currentTimingPointIndex = 1
	local currentTimingPoint = self.timingPoints[1]
	local nextTimingPoint = self.timingPoints[2]
	for _, note in ipairs(self.hitObjects) do
		if nextTimingPoint and note.startTime >= nextTimingPoint.offset then
			currentTimingPoint = nextTimingPoint
			currentTimingPointIndex = currentTimingPointIndex + 1
			nextTimingPoint = self.timingPoints[currentTimingPointIndex + 1]
		end
		
		note.timingPoint = currentTimingPoint
		self:setSounds(note)
	end
end

Osu.processLine = function(self, line)
	if line:find("^%[") then
		local currentBlockName, lineEnd = line:match("^%[(.+)%](.*)$")
		self.currentBlockName = currentBlockName
		self:processLine(lineEnd)
	else
		if line:trim() == "" then
			--skip
		elseif line:find("^%a+:.*$") then
			self:addMetadata(line)
		elseif self.currentBlockName == "Events" then
			self:addEvent(line)
		elseif self.currentBlockName == "TimingPoints" then
			self:addTimingPoint(line)
		elseif self.currentBlockName == "HitObjects" then
			self:addHitObject(line)
		end
	end
end

Osu.addMetadata = function(self, line)
	local key, value = line:match("^(%a+):%s?(.*)")
	self.metadata[key] = value
	if key == "Mode" then
		self.mode = tonumber(value)
	end
	if key == "CircleSize" and self.mode == 3 then
		self.keymode = tonumber(value)
	end
end

Osu.addEvent = function(self, line)
	local split = line:split(",")
	
	if split[1] == "5" or split[1] == "Sample" then
		local event = {}
		
		event.type = "sample"
		event.startTime = tonumber(split[2])
		event.sound = split[4]:match("\"(.+)\"")
		event.volume = tonumber(split[5]) or 100
		
		self.events[#self.events + 1] = event
	elseif split[1] == "0" then
		self.background = line:match("^0,.+,\"(.+)\".*$")
	end
end

Osu.addTimingPoint = function(self, line)
	local split = line:split(",")
	local tp = {}
	
	tp.offset = tonumber(split[1])
	tp.beatLength = tonumber(split[2])
	tp.timingSignature = math.max(0, tonumber(split[3]) or 4)
	tp.sampleSetId = math.max(0, tonumber(split[4]) or 0)
	tp.customSampleIndex = math.max(0, tonumber(split[5]) or 0)
	tp.sampleVolume = math.max(0, tonumber(split[6]) or 100)
	tp.timingChange = tonumber(split[7]) or 1
	tp.kiaiTimeActive = tonumber(split[8]) or 0
	
	if tp.timingSignature == 0 then
		tp.timingSignature = 4
	end
	
	if tp.beatLength >= 0 then
		tp.beatLength = math.abs(tp.beatLength)
		tp.measureLength = math.abs(tp.beatLength * tp.timingSignature)
		tp.timingChange = true
		if tp.beatLength < 1e-3 then
			tp.beatLength = 1
		end
		if tp.measureLength < 1e-3 then
			tp.measureLength = 1
		end
	else
		tp.velocity = math.min(math.max(0.1, math.abs(-100 / tp.beatLength)), 10)
		tp.timingChange = false
	end
	
	self.timingPoints[#self.timingPoints + 1] = tp
end

Osu.addHitObject = function(self, line)
	local split = line:split(",")
	local note = {}
	local addition
	
	note.x = tonumber(split[1])
	note.y = tonumber(split[2])
	note.startTime = tonumber(split[3])
	
	note.type = tonumber(split[4])
	if bit.band(note.type, 2) == 2 then
		note.repeatCount = tonumber(split[7])
		local length = tonumber(split[8])
		note.endTime = length and note.startTime + length
		addition = split[11] and split[11]:split(":") or {}
	elseif bit.band(note.type, 128) == 128 then
		addition = split[6] and split[6]:split(":") or {}
		note.endTime = tonumber(addition[1])
		table.remove(addition, 1)
	elseif bit.band(note.type, 8) == 8 then
		addition = split[7] and split[7]:split(":") or {}
		note.endTime = tonumber(split[6])
	else
		addition = split[6] and split[6]:split(":") or {}
	end
	
	note.hitSoundBitmap = tonumber(split[5])
	note.sampleSetId = tonumber(addition[1]) or 0
	note.additionalSampleSetId = tonumber(addition[2]) or 0
	note.customSampleSetIndex = tonumber(addition[3]) or 0
	note.hitSoundVolume = tonumber(addition[4]) or 0
	note.customHitSound = addition[5] or ""
	
	note.key = math.floor(note.x / 512 * self.keymode + 1)
	
	self.hitObjects[#self.hitObjects + 1] = note
end

Osu.setDefaultMetadata = function(self)
	self.metadata = {
		AudioFilename = "",
		PreviewTime = "0",
		Mode = "3",
		Title = "",
		TitleUnicode = "",
		Artist = "",
		ArtistUnicode = "",
		Creator = "",
		Version = "",
		Source = "",
		Tags = "",
		CircleSize = "0"
	}
end

Osu.checkMissing = function(self)
	if #self.timingPoints == 0 then
		self:addTimingPoint("0,1000,4,2,0,100,1,0")
	end
end

local soundBits = {
	{2, "whistle"},
	{4, "finish"},
	{8, "clap"},
	{0, "normal"}
}

Osu.setSounds = function(self, note)
	note.sounds = {}
	note.fallbackSounds = {}
	
	if note.hitSoundVolume > 0 then
		note.volume = note.hitSoundVolume
	elseif note.timingPoint.sampleVolume > 0 then
		note.volume = note.timingPoint.sampleVolume
	elseif note.customHitSound and note.customHitSound ~= "" then
		note.volume = 100
	else
		note.volume = 5
	end
	
	if note.customHitSound and note.customHitSound ~= "" then
		note.sounds[1] = {note.customHitSound, note.volume}
		note.fallbackSounds[#note.fallbackSounds + 1] = {note.customHitSound, note.volume}
		note.keysound = true
		return
	end
	
	local sampleSetId
	if note.hitSoundBitmap > 0 and note.additionalSampleSetId ~= 0 then
		sampleSetId = note.additionalSampleSetId
	elseif note.sampleSetId ~= 0 then
		sampleSetId = note.sampleSetId
	else
		sampleSetId = note.timingPoint.sampleSetId
	end
	note.sampleSetName = self:getSampleSetName(sampleSetId)
	
	if note.timingPoint.customSampleIndex ~= 0 then
		note.customSampleIndex = note.timingPoint.customSampleIndex
	else
		note.customSampleIndex = ""
	end
	
	for i = 1, 4 do
		local mask = soundBits[i][1]
		local name = soundBits[i][2]
		if
			i < 4 and bit.band(note.hitSoundBitmap, mask) == mask or
			i == 4 and #note.sounds == 0
		then
			note.sounds[#note.sounds + 1]
				= {note.sampleSetName .. "-hit" .. name .. note.customSampleIndex, note.volume}
			note.fallbackSounds[#note.fallbackSounds + 1]
				= {note.sampleSetName .. "-hit" .. name, note.volume}
		end
	end
end

Osu.getSampleSetName = function(self, id)
	if id == 0 then
		return "none"
	elseif id == 1 then
		return "normal"
	elseif id == 2 then
		return "soft"
	elseif id == 3 then
		return "drum"
	end

	return "normal"
end

return Osu
