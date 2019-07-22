local ncdk = require("ncdk")
local enums = require("bms.enums")
local BMS = require("bms.BMS")
local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}
	
	setmetatable(noteChartImporter, NoteChartImporter_metatable)
	
	return noteChartImporter
end

NoteChartImporter.import = function(self, noteChartString)
	self.foregroundLayerData = self.noteChart.layerDataSequence:requireLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")
	
	self.bms = BMS:new()
	self.bms.pms = self.pms
	self.bms:import(noteChartString)
	
	self.noteChart.inputMode:setInputCount("key", self.bms.mode)
	if self.pms then
		-- skip
	elseif self.bms.mode > 7 then
		self.noteChart.inputMode:setInputCount("scratch", 2)
	else
		self.noteChart.inputMode:setInputCount("scratch", 1)
	end
	
	self:addFirstTempo()
	
	self:processData()
	self.noteChart:hashSet("noteCount", self.noteCount)
	
	self:processMeasureLines()
	
	self.noteChart.type = "bms"
	
	self.noteChart:compute()
	
	if self.maxTimePoint and self.minTimePoint then
		self.totalLength = self.maxTimePoint:getAbsoluteTime() - self.minTimePoint:getAbsoluteTime()
	else
		self.totalLength = 0
	end
	self.noteChart:hashSet("totalLength", self.totalLength)
end

NoteChartImporter.setTempo = function(self, timeData)
	if timeData[enums.BackChannelEnum["Tempo"]] then
		local value = timeData[enums.BackChannelEnum["Tempo"]][1]
		self.currentTempoData = ncdk.TempoData:new(
			timeData.measureTime,
			tonumber(value, 16)
		)
		self.foregroundLayerData:addTempoData(self.currentTempoData)
		
		local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
		self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.bms.primaryTempo, 1000))
		self.foregroundLayerData:addVelocityData(self.currentVelocityData)
	end
end

NoteChartImporter.setExtendedTempo = function(self, timeData)
	if timeData[enums.BackChannelEnum["ExtendedTempo"]] then
		local value = timeData[enums.BackChannelEnum["ExtendedTempo"]][1]
		self.currentTempoData = ncdk.TempoData:new(
			timeData.measureTime,
			self.bms.bpm[value]
		)
		self.foregroundLayerData:addTempoData(self.currentTempoData)
		
		local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
		self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.bms.primaryTempo, 1000))
		self.foregroundLayerData:addVelocityData(self.currentVelocityData)
	end
end

NoteChartImporter.setStop = function(self, timeData)
	if timeData[enums.BackChannelEnum["Stop"]] then
		local value = timeData[enums.BackChannelEnum["Stop"]][1]
		local measureDuration = ncdk.Fraction:new(self.bms.stop[value], 192)
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
		self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.bms.primaryTempo, 1000))
		self.foregroundLayerData:addVelocityData(self.currentVelocityData)
	end
end

NoteChartImporter.processData = function(self)
	local longNoteData = {}
	
	self.noteCount = 0
	
	self.minTimePoint = nil
	self.maxTimePoint = nil
	
	for measureIndex, value in pairs(self.bms.signature) do
		self.foregroundLayerData:setSignature(
			measureIndex,
			ncdk.Fraction:fromNumber(value * 4, 32768)
		)
	end
	
	for _, timeData in ipairs(self.bms.timeList) do
		self:setTempo(timeData)
		self:setExtendedTempo(timeData)
		self:setStop(timeData)
		
		for channelIndex, indexDataValues in pairs(timeData) do
			local channelInfo
			if self.bms.mode == 10 and enums.ChannelEnum5Keys[channelIndex] then
				channelInfo = enums.ChannelEnum5Keys[channelIndex]
			else
				channelInfo = enums.ChannelEnum[channelIndex]
			end
			
			if channelInfo and (
				channelInfo.name == "Note" or
				channelInfo.name == "BGM" or
				channelInfo.name == "BGA"
			)
			then
				for _, value in ipairs(indexDataValues) do
					local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime, -1)
					
					local noteData = ncdk.NoteData:new(timePoint)
					noteData.inputType = channelInfo.inputType
					noteData.inputIndex = channelInfo.inputIndex
					
					noteData.sounds = {}
					noteData.images = {}
					if channelInfo.name == "Note" or channelInfo.name == "BGM" then
						local sound = self.bms.wav[value]
						if sound and not channelInfo.mine then
							noteData.sounds[1] = {sound, 1}
							self.noteChart:addResource("sound", sound, {sound})
						end
					elseif channelInfo.name == "BGA" then
						local image = self.bms.bmp[value]
						if image then
							noteData.images[1] = {image, 1}
							self.noteChart:addResource("image", image, {image})
						end
					end
					
					if channelInfo.name == "BGA" then
						noteData.noteType = "ImageNote"
					elseif channelInfo.inputType == "auto" or channelInfo.mine then
						noteData.noteType = "SoundNote"
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
					else
						if longNoteData[channelIndex] and value == self.bms.lnobj then
							longNoteData[channelIndex].noteType = "LongNoteStart"
							longNoteData[channelIndex].endNoteData = noteData
							noteData.startNoteData = longNoteData[channelIndex]
							noteData.noteType = "LongNoteEnd"
							longNoteData[channelIndex] = nil
						else
							noteData.noteType = "ShortNote"
							longNoteData[channelIndex] = noteData
						end
					end
					self.foregroundLayerData:addNoteData(noteData)
					
					if
						channelInfo.inputType ~= "auto" and
						not channelInfo.mine and
						noteData.noteType ~= "LongNoteEnd" and
						channelInfo.name ~= "BGA"
					then
						self.noteCount = self.noteCount + 1
						
						if not self.minTimePoint or timePoint < self.minTimePoint then
							self.minTimePoint = timePoint
						end
						
						if not self.maxTimePoint or timePoint > self.maxTimePoint then
							self.maxTimePoint = timePoint
						end
					end
				end
			end
		end
	end
end

NoteChartImporter.processMeasureLines = function(self)
	for measureIndex = 0, self.bms.measureCount do
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

NoteChartImporter.addFirstTempo = function(self)
	if not self.bms.tempoAtStart and self.bms.baseTempo then
		local measureTime = ncdk.Fraction:new(0)
		self.currentTempoData = ncdk.TempoData:new(measureTime, self.bms.baseTempo)
		self.foregroundLayerData:addTempoData(self.currentTempoData)
		
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime, 1)
		self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.bms.baseTempo / self.bms.primaryTempo, 1000))
		self.foregroundLayerData:addVelocityData(self.currentVelocityData)
	end
end

return NoteChartImporter
