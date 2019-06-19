local Osu = {}

local Osu_metatable = {}
Osu_metatable.__index = Osu

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
	self:process()
end

Osu.process = function(self)
	for _, line in ipairs(self.noteChartString:split("\n")) do
		self:processLine(line)
	end
end

Osu.processLine = function(self, line)
	if line:find("^%[") then
		self.currentBlockName = line:match("^%[(.+)%]")
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
end

Osu.addEvent = function(self, line)
	local split = line:split(",")
	
	if line[1] == "5" or line[1] == "Sample" then
		local event = {}
		
		event.type = "sample"
		event.time = tonumber(split[2])
		event.sound = split[4]:match("\"(.+)\"")
		event.volume = tonumber(split[5])
		
		self.events[#self.events + 1] = event
	elseif line[1] == "0" then
		self.background = line:match("^0,.+,\"(.+)\",.+$")
	end
end

Osu.addTimingPoint = function(self, line)
	local split = line:split(",")
	local tp = {}
	
	tp.offset = tonumber(split[1])
	tp.beatLength = tonumber(split[2])
	tp.timingSignature = tonumber(split[3])
	tp.sampleSetId = tonumber(split[4])
	tp.customSampleIndex = tonumber(split[5])
	tp.sampleVolume = tonumber(split[6])
	tp.timingChange = tonumber(split[7])
	tp.kiaiTimeActive = tonumber(split[8])
	
	if tp.beatLength >= 0 then
		tp.beatLength = math.abs(tp.beatLength)
		tp.measureLength = math.abs(tp.beatLength * tp.timingSignature)
		tp.timingChange = true
	else
		tp.velocity = math.min(math.max(0.1, math.abs(-100 / tp.beatLength)), 10)
		tp.timingChange = false
	end
	
	self.timingPoints[#self.timingPoints + 1] = tp
end

Osu.addHitObject = function(self, line)
	local split = line:split(",")
	local addition = split[6]:split(":")
	local note = {}
	
	note.x = tonumber(split[1])
	note.y = tonumber(split[2])
	note.startTime = tonumber(split[3])
	note.type = tonumber(split[4])
	note.hitSoundBitmap = tonumber(split[5])
	if bit.band(note.type, 128) == 128 then
		note.endTime = tonumber(addition[1])
		table.remove(addition, 1)
	end
	note.sampleSetId = tonumber(addition[1])
	note.additionalSampleSetId = tonumber(addition[2])
	note.customSampleSetIndex = tonumber(addition[3])
	note.hitSoundVolume = tonumber(addition[4])
	note.customHitSound = addition[5]
	
	local keymode = self.metadata["CircleSize"]
	note.key = math.ceil(note.x / 512 * keymode)
	
	self.hitObjects[#self.hitObjects + 1] = note
end

return Osu
