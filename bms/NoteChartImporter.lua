local ncdk = require("ncdk")
local enums = require("bms.enums")
local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}
	
	noteChartImporter.wavDataSequence = {}
	noteChartImporter.bpmDataSequence = {}
	noteChartImporter.stopDataSequence = {}
	
	noteChartImporter.primaryTempo = 120
	noteChartImporter.measureCount = 0
	
	noteChartImporter.data = {}
	noteChartImporter.data.timeMatch = {}
	
	noteChartImporter.inputMode = {}
	
	setmetatable(noteChartImporter, NoteChartImporter_metatable)
	
	return noteChartImporter
end

NoteChartImporter.import = function(self, noteChartString)
	self.foregroundLayerData = self.noteChart.layerDataSequence:requireLayerData(1)
	self.backgroundLayerData = self.noteChart.layerDataSequence:requireLayerData(2)
	self.backgroundLayerData.invisible = true
	
	self.foregroundLayerData.timeData:setMode(ncdk.TimeData.Modes.Measure)
	self.backgroundLayerData.timeData:setMode(ncdk.TimeData.Modes.Measure)
	
	self.backgroundLayerData.timeData = self.foregroundLayerData.timeData
	
	for _, line in ipairs(noteChartString:split("\n")) do
		self:processLine(line:trim())
	end
	
	table.sort(self.data, function(a, b)
		return a.measureTime < b.measureTime
	end)
	
	self:importBaseTimingData()
	self:processData()
	self:processMeasureLines()
	
	for inputType, inputCount in pairs(self.inputMode) do
		self.noteChart.inputMode:setInputCount(inputType, inputCount)
	end
	self.noteChart.type = "bms"
	
	self.noteChart:compute()
end

NoteChartImporter.processLine = function(self, line)
	if line:find("^#WAV.. .+$") then
		local index, fileName = line:match("^#WAV(..) (.+)$")
		self.wavDataSequence[index] = fileName
	elseif line:find("^#BPM.. .+$") then
		local index, tempo = line:match("^#BPM(..) (.+)$")
		self.bpmDataSequence[index] = tonumber(tempo)
	elseif line:find("^#STOP.. .+$") then
		local index, duration = line:match("^#STOP(..) (.+)$")
		self.stopDataSequence[index] = tonumber(duration)
	elseif line:find("^#%d%d%d..:.+$") then
		self:processLineData(line)
	elseif line:find("^#[%S]+ .+$") then
		self:processHeaderLine(line)
	end
end

NoteChartImporter.updateInputMode = function(self, channelIndex)
	local inputIndex = enums.ChannelEnum[channelIndex].inputIndex
	if inputIndex then
		self.inputMode.key = self.inputMode.key or 5
		self.inputMode.scratch = self.inputMode.scratch or 1
		if inputIndex > self.inputMode.key then
			if inputIndex > 12 then
				self.inputMode.key = 14
				self.inputMode.scratch = 2
			elseif inputIndex > 7 then
				self.inputMode.key = 10
				self.inputMode.scratch = 2
			elseif inputIndex > 5 then
				self.inputMode.key = 7
			end
		end
	end
end

NoteChartImporter.processLineData = function(self, line)
	local measureIndex, channelIndex, indexDataString = line:match("^#(%d%d%d)(..):(.+)$")
	measureIndex = tonumber(measureIndex)
	
	if measureIndex > self.measureCount then
		self.measureCount = measureIndex
	end
	
	if not enums.ChannelEnum[channelIndex] then
		return
	end
	
	self:updateInputMode(channelIndex)
	
	if enums.ChannelEnum[channelIndex].name == "Signature" then
		self.foregroundLayerData:setSignature(
			measureIndex,
			ncdk.Fraction:new():fromNumber(tonumber((indexDataString:gsub(",", "."))) * 4, 32768)
		)
		return
	end
	
	local compound = enums.ChannelEnum[channelIndex].name ~= "BGM"
	
	local messageLength = math.floor(#indexDataString / 2)
	for indexDataIndex = 1, messageLength do
		local value = indexDataString:sub(2 * indexDataIndex - 1, 2 * indexDataIndex)
		if value ~= "00" then
			local measureTime = ncdk.Fraction:new(indexDataIndex - 1, messageLength) + measureIndex
			local measureTimeString = tostring(measureTime)
			
			local timeData
			if self.data.timeMatch[measureTimeString] then
				timeData = self.data.timeMatch[measureTimeString]
			else
				timeData = {}
				self.data.timeMatch[measureTimeString] = timeData
				table.insert(self.data, timeData)
				
				timeData.measureTime = measureTime
			end
			local currentNoteChannelIndex
			for currentChannelIndex, indexDataValues in pairs(timeData) do
				if
					enums.ChannelEnum[currentChannelIndex] and
					enums.ChannelEnum[currentChannelIndex].name == "Note" and
					enums.ChannelEnum[channelIndex].inputType == enums.ChannelEnum[currentChannelIndex].inputType and
					enums.ChannelEnum[channelIndex].inputIndex == enums.ChannelEnum[currentChannelIndex].inputIndex
				then
					currentNoteChannelIndex = currentChannelIndex
					break
				end
			end
			
			timeData[channelIndex] = timeData[channelIndex] or {}
			if compound then
				if enums.ChannelEnum[channelIndex].name == "Note" then
					if enums.ChannelEnum[channelIndex].long then
						if currentNoteChannelIndex then
							timeData[currentNoteChannelIndex][1] = nil
							timeData[currentNoteChannelIndex] = nil
						end
						timeData[channelIndex][1] = value
					end
					if not enums.ChannelEnum[channelIndex].long and not currentNoteChannelIndex then
						timeData[channelIndex][1] = value
					end
				else
					timeData[channelIndex][1] = value
				end
			else
				table.insert(timeData[channelIndex], value)
			end
		end
	end
end

NoteChartImporter.processData = function(self)
	local longNoteData = {}
	
	for _, timeData in ipairs(self.data) do
		if timeData[enums.BackChannelEnum["Tempo"]] then
			local value = timeData[enums.BackChannelEnum["Tempo"]][1]
			self.currentTempoData = ncdk.TempoData:new(
				timeData.measureTime,
				tonumber(value, 16)
			)
			self.foregroundLayerData:addTempoData(self.currentTempoData)
			
			local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
			self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.primaryTempo, 1000))
			self.foregroundLayerData:addVelocityData(self.currentVelocityData)
		end
		if timeData[enums.BackChannelEnum["ExtendedTempo"]] then
			local value = timeData[enums.BackChannelEnum["ExtendedTempo"]][1]
			self.currentTempoData = ncdk.TempoData:new(
				timeData.measureTime,
				self.bpmDataSequence[value]
			)
			self.foregroundLayerData:addTempoData(self.currentTempoData)
			
			local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
			self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.primaryTempo, 1000))
			self.foregroundLayerData:addVelocityData(self.currentVelocityData)
		end
		if timeData[enums.BackChannelEnum["Stop"]] then
			local value = timeData[enums.BackChannelEnum["Stop"]][1]
			local measureDuration = ncdk.Fraction:new(self.stopDataSequence[value], 192)
			local stopData = ncdk.StopData:new(timeData.measureTime, measureDuration)
			stopData.tempoData = self.currentTempoData
			stopData.signature = ncdk.Fraction:new(4)
			self.foregroundLayerData:addStopData(stopData)
			
			local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
			if self.currentVelocityData.timePoint == timePoint then
				self.foregroundLayerData:removeLastVelocityData()
			end
			self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new(0))
			self.foregroundLayerData:addVelocityData(self.currentVelocityData)
			
			local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime)
			self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.primaryTempo, 1000))
			self.foregroundLayerData:addVelocityData(self.currentVelocityData)
		end
		
		for channelIndex, indexDataValues in pairs(timeData) do
			local channelInfo
			if self.inputMode.key == 10 and enums.ChannelEnum5Keys[channelIndex] then
				channelInfo = enums.ChannelEnum5Keys[channelIndex]
			else
				channelInfo = enums.ChannelEnum[channelIndex]
			end
			
			if channelInfo and (channelInfo.name == "Note" or channelInfo.name == "BGM") then
				for _, value in ipairs(indexDataValues) do
					local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
					
					local noteData = ncdk.NoteData:new(timePoint)
					noteData.inputType = channelInfo.inputType
					noteData.inputIndex = channelInfo.inputIndex
					
					local sound = self.wavDataSequence[value]
					noteData.sounds = {}
					if sound and not channelInfo.mine then
						noteData.sounds[1] = sound
						self.noteChart:addResource("sound", sound)
					end
					
					if channelInfo.inputType == "auto" then
						noteData.noteType = "SoundNote"
						self.backgroundLayerData:addNoteData(noteData)
					elseif channelInfo.mine then
						noteData.noteType = "SoundNote"
						self.foregroundLayerData:addNoteData(noteData)
					elseif channelInfo.long then
						if not longNoteData[channelIndex] then
							noteData.noteType = "LongNoteStart"
							longNoteData[channelIndex] = noteData
						else
							noteData.noteType = "LongNoteEnd"
							noteData.startNoteData = longNoteData[channelIndex]
							longNoteData[channelIndex].endNoteData = noteData
							longNoteData[channelIndex] = nil
						end
						self.foregroundLayerData:addNoteData(noteData)
					else
						if longNoteData[channelIndex] and value == self.lnobj then
							longNoteData[channelIndex].noteType = "LongNoteStart"
							longNoteData[channelIndex].endNoteData = noteData
							noteData.startNoteData = longNoteData[channelIndex]
							noteData.noteType = "LongNoteEnd"
							longNoteData[channelIndex] = nil
						else
							noteData.noteType = "ShortNote"
							longNoteData[channelIndex] = noteData
						end
						self.foregroundLayerData:addNoteData(noteData)
					end
				end
			end
		end
	end
end

NoteChartImporter.processMeasureLines = function(self)
	for measureIndex = 0, self.measureCount do
		local measureTime = ncdk.Fraction:new(measureIndex)
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
		
		local startNoteData = ncdk.NoteData:new(timePoint)
		startNoteData.inputType = "measure"
		startNoteData.inputIndex = 1
		startNoteData.noteType = "LineNoteStart"
		self.foregroundLayerData:addNoteData(startNoteData)
		
		local endNoteData = ncdk.NoteData:new(timePoint)
		endNoteData.inputType = "measure"
		endNoteData.inputIndex = 1
		endNoteData.noteType = "LineNoteEnd"
		self.foregroundLayerData:addNoteData(endNoteData)
		
		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData
	end
end

NoteChartImporter.processHeaderLine = function(self, line)
	local key, value = line:match("^#(%S+) (.+)$")
	self.noteChart:hashSet(key, value)
	
	if key == "BPM" then
		self.baseTempo = tonumber(value)
	elseif key == "LNOBJ" then
		self.lnobj = value
	end
end

NoteChartImporter.importBaseTimingData = function(self)
	if self.baseTempo then
		local measureTime = ncdk.Fraction:new(-1, 6)
		self.currentTempoData = ncdk.TempoData:new(measureTime, self.baseTempo)
		self.foregroundLayerData:addTempoData(self.currentTempoData)
		
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime, 1)
		self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.baseTempo / self.primaryTempo, 1000))
		self.foregroundLayerData:addVelocityData(self.currentVelocityData)
	end
end

return NoteChartImporter
