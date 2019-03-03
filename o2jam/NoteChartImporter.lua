local ncdk = require("ncdk")
local OJM = require("o2jam.OJM")
local OJN = require("o2jam.OJN")

local NoteChartImporter = {}

local NoteChartImporter_metatable = {}
NoteChartImporter_metatable.__index = NoteChartImporter

NoteChartImporter.new = function(self)
	local noteChartImporter = {}
	
	noteChartImporter.primaryTempo = 120
	noteChartImporter.measureCount = 0
	
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
	
	self.ojn = OJN:new(noteChartString)
	self:processMetaData()
	self:processData()
	self:processMeasureLines()
	
	self.noteChart.inputMode:setInputCount("key", 7)
	self.noteChart.type = "o2jam"
	
	self.noteChart:compute()
end

NoteChartImporter.processMetaData = function(self)
	self.noteChart:hashSet("genre", self.ojn.str_genre)
	self.noteChart:hashSet("bpm", self.ojn.bpm)
	self.noteChart:hashSet("title", self.ojn.str_title)
	self.noteChart:hashSet("artist", self.ojn.str_artist)
	self.noteChart:hashSet("noter", self.ojn.str_noter)
	self.noteChart:hashSet("level", self.ojn.charts[self.chartIndex].level)
	self.noteChart:hashSet("notes", self.ojn.charts[self.chartIndex].notes)
	self.noteChart:hashSet("duration", self.ojn.charts[self.chartIndex].duration)
end

NoteChartImporter.addFirstTempo = function(self)
	local measureTime = ncdk.Fraction:new(0)
	self.currentTempoData = ncdk.TempoData:new(
		measureTime,
		self.ojn.bpm
	)
	self.foregroundLayerData:addTempoData(self.currentTempoData)
	
	local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
	self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.primaryTempo, 1000))
	self.foregroundLayerData:addVelocityData(self.currentVelocityData)
end

NoteChartImporter.processData = function(self)
	local longNoteData = {}
	
	self:addFirstTempo()
	for _, event in ipairs(self.ojn.charts[self.chartIndex].event_list) do
		if event.measure > self.measureCount then
			self.measureCount = event.measure
		end
		
		local measureTime = ncdk.Fraction:new():fromNumber(event.measure + event.position, 1000)
		if event.channel == "BPM_CHANGE" then
			self.currentTempoData = ncdk.TempoData:new(
				measureTime,
				event.value
			)
			self.foregroundLayerData:addTempoData(self.currentTempoData)
			
			local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
			self.currentVelocityData = ncdk.VelocityData:new(timePoint, ncdk.Fraction:new():fromNumber(self.currentTempoData.tempo / self.primaryTempo, 1000))
			self.foregroundLayerData:addVelocityData(self.currentVelocityData)
		end
		if event.channel == "TIME_SIGNATURE" then
			self.foregroundLayerData:setSignature(
				event.measure,
				ncdk.Fraction:new():fromNumber(event.value * 4, 32768)
			)
		end
		if event.channel:find("NOTE") or event.channel:find("AUTO") then
			local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
			
			local noteData = ncdk.NoteData:new(timePoint)
			noteData.inputType = event.channel:find("NOTE") and "key" or "auto"
			noteData.inputIndex = event.channel:find("NOTE") and tonumber(event.channel:sub(-1, -1)) or 0
			
			noteData.sounds = {event.value}
			
			if noteData.inputType == "auto" then
				noteData.noteType = "SoundNote"
				self.backgroundLayerData:addNoteData(noteData)
			else
				if longNoteData[noteData.inputIndex] and event.type == "RELEASE" then
					longNoteData[noteData.inputIndex].noteType = "LongNoteStart"
					longNoteData[noteData.inputIndex].endNoteData = noteData
					noteData.startNoteData = longNoteData[noteData.inputIndex]
					noteData.noteType = "LongNoteEnd"
					longNoteData[noteData.inputIndex] = nil
				else
					noteData.noteType = "ShortNote"
					if event.type == "HOLD" then
						longNoteData[noteData.inputIndex] = noteData
					end
				end
				self.foregroundLayerData:addNoteData(noteData)
			end
		end
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

return NoteChartImporter
