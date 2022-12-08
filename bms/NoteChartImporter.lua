local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local enums = require("bms.enums")
local BMS = require("bms.BMS")
local EncodingConverter = require("notechart.EncodingConverter")
local dpairs = require("dpairs")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}

	setmetatable(noteChartImporter, NoteChartImporter_metatable)

	return noteChartImporter
end

NoteChartImporter.import = function(self)
	self.noteChart = NoteChart:new()
	local noteChart = self.noteChart

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")
	self.foregroundLayerData:setSignatureMode("short")
	self.foregroundLayerData:setPrimaryTempo(130)

	if not self.bms then
		self.bms = BMS:new()
		self.bms.pms = self.path:lower():sub(-4, -1) == ".pms"
		self.bms:import(self.content:gsub("\r[\r\n]?", "\n"))
	end

	self:setInputMode()
	self:addFirstTempo()
	self:processData()
	self:processMeasureLines()

	noteChart.type = "bms"
	noteChart:compute()

	self:updateLength()

	noteChart.index = 1
	noteChart.metaData = MetaData(noteChart, self)

	self.noteCharts = {noteChart}
end

NoteChartImporter.setInputMode = function(self)
	local mode = self.bms.mode
	local inputMode = self.noteChart.inputMode
	inputMode.key = mode

	self.ChannelEnum = enums.ChannelEnum
	if mode == 5 then
		inputMode.scratch = 1
		self.ChannelEnum = enums.ChannelEnum5Keys
	elseif mode == 7 then
		inputMode.scratch = 1
	elseif mode == 10 then
		inputMode.scratch = 2
		self.ChannelEnum = enums.ChannelEnum5Keys
	elseif mode == 14 then
		inputMode.scratch = 2
	elseif mode == 59 then
		inputMode.key = mode - 50
		self.ChannelEnum = enums.ChannelEnum9Keys
	elseif mode == 55 then
		inputMode.key = mode - 50
		self.ChannelEnum = enums.ChannelEnumPMS5Keys
	elseif mode == 25 or mode == 27 then
		inputMode.key = mode - 20
		inputMode.scratch = 1
		inputMode.pedal = 1
		self.ChannelEnum = enums.ChannelEnumDsc
	end
end

NoteChartImporter.updateLength = function(self)
	if self.maxTimePoint and self.minTimePoint then
		self.totalLength = self.maxTimePoint.absoluteTime - self.minTimePoint.absoluteTime
		self.minTime = self.minTimePoint.absoluteTime
		self.maxTime = self.maxTimePoint.absoluteTime
	else
		self.totalLength = 0
		self.minTime = 0
		self.maxTime = 0
	end
end

NoteChartImporter.setTempo = function(self, timeData)
	if not timeData[enums.BackChannelEnum["Tempo"]] then
		return
	end
	local tempo = tonumber(timeData[enums.BackChannelEnum["Tempo"]][1], 16)
	local ld = self.foregroundLayerData
	ld:insertTempoData(timeData.measureTime, tempo)
end

NoteChartImporter.setExtendedTempo = function(self, timeData)
	if not timeData[enums.BackChannelEnum["ExtendedTempo"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["ExtendedTempo"]][1]
	local tempo = self.bms.bpm[value]
	if not tempo then
		return
	end

	local ld = self.foregroundLayerData

	ld:insertTempoData(timeData.measureTime, tempo)
	return true
end

NoteChartImporter.setStop = function(self, timeData)
	if not timeData[enums.BackChannelEnum["Stop"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["Stop"]][1]
	local duration = self.bms.stop[value]
	if not duration then
		return
	end

	local ld = self.foregroundLayerData

	duration = duration * 4
	local measureDuration
	if duration % 1 == 0 then
		measureDuration = ncdk.Fraction:new(duration, 192)
	else
		measureDuration = ncdk.Fraction:new(duration, 1e6, true) / 192
	end

	ld:insertStopData(timeData.measureTime, measureDuration)
end

NoteChartImporter.processData = function(self)
	local longNoteData = {}

	self.noteCount = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil

	for measureIndex, value in pairs(self.bms.signature) do
		self.foregroundLayerData:setSignature(
			measureIndex,
			ncdk.Fraction:new(value * 4, 32768, true)
		)
	end

	for _, timeData in ipairs(self.bms.timeList) do
		if not self:setExtendedTempo(timeData) then
			self:setTempo(timeData)
		end
		self:setStop(timeData)

		for channelIndex, indexDataValues in dpairs(timeData) do
			local channelInfo = self.ChannelEnum[channelIndex] or enums.ChannelEnum[channelIndex]

			if channelInfo and (
				channelInfo.name == "Note" and channelInfo.invisible ~= true or
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
						local sound = EncodingConverter:fix(self.bms.wav[value])
						if sound and not channelInfo.mine then
							noteData.sounds[1] = {sound, 1}
							self.noteChart:addResource("sound", sound, {sound})
						end
					elseif channelInfo.name == "BGA" then
						local image = EncodingConverter:fix(self.bms.bmp[value])
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
							noteData.sounds = {}
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
							noteData.sounds = {}
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
						channelInfo.name ~= "BGA"
					then
						if noteData.noteType ~= "LongNoteEnd" then
							self.noteCount = self.noteCount + 1
						end

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
	for _, noteData in pairs(longNoteData) do
		noteData.noteType = "ShortNote"
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
		local ld = self.foregroundLayerData

		ld:insertTempoData(measureTime, self.bms.baseTempo)
	end
end

return NoteChartImporter
