local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local MetaData = require("notechart.MetaData")
local OJM = require("o2jam.OJM")
local OJN = require("o2jam.OJN")
local bmsNoteChartImporter = require("bms.NoteChartImporter")

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

NoteChartImporter.import = function(self)
	local noteCharts = {}

	local ojn = OJN:new(self.content)

	local i0, i1 = 1, 3
	if self.index then
		i0, i1 = self.index, self.index
	end

	for i = i0, i1 do
		local importer = NoteChartImporter:new()
		importer.ojn = ojn
		noteCharts[#noteCharts + 1] = importer:importSingle(i)
	end

	self.noteCharts = noteCharts
end

NoteChartImporter.importSingle = function(self, index)
	self.chartIndex = index

	self.noteChart = NoteChart:new()
	local noteChart = self.noteChart

	noteChart.importer = self
	noteChart.metaData = MetaData:new()
	noteChart.metaData.noteChart = noteChart

	if not self.ojn then
		self.ojn = OJN:new(self.content)
	end

	self.foregroundLayerData = noteChart.layerDataSequence:requireLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")

	self:processData()

	self:processMeasureLines()

	noteChart.inputMode:setInputCount("key", 7)
	noteChart.type = "o2jam"

	noteChart:compute()

	self:updateLength()

	noteChart.index = index
	noteChart.metaData:fillData()

	return noteChart
end

NoteChartImporter.updateLength = bmsNoteChartImporter.updateLength

NoteChartImporter.addFirstTempo = function(self)
	local measureTime = ncdk.Fraction:new(0)
	self.currentTempoData = ncdk.TempoData:new(
		measureTime,
		self.ojn.bpm
	)
	self.foregroundLayerData:addTempoData(self.currentTempoData)

	local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
	self.currentVelocityData = ncdk.VelocityData:new(timePoint)
	self.currentVelocityData.currentSpeed = self.currentTempoData.tempo / self.primaryTempo
	self.foregroundLayerData:addVelocityData(self.currentVelocityData)
end

NoteChartImporter.processData = function(self)
	local longNoteData = {}

	self.noteCount = 0

	self.minTimePoint = nil
	self.maxTimePoint = nil
	self.tempoAtStart = false

	local measureCount = self.ojn.charts[self.chartIndex].measure_count

	for _, event in ipairs(self.ojn.charts[self.chartIndex].event_list) do
		local measureTime = ncdk.Fraction:new(event.measure + event.position, 1000, true)
		if event.measure < 0 or event.measure > measureCount * 2 then
			-- ignore
		elseif event.channel == "BPM_CHANGE" then
			if measureTime:tonumber() == 0 then
				self.tempoAtStart = true
			end

			self.currentTempoData = ncdk.TempoData:new(
				measureTime,
				event.value
			)
			self.foregroundLayerData:addTempoData(self.currentTempoData)

			local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)
			self.currentVelocityData = ncdk.VelocityData:new(timePoint)
			self.currentVelocityData.currentSpeed = self.currentTempoData.tempo / self.primaryTempo
			self.foregroundLayerData:addVelocityData(self.currentVelocityData)
		elseif event.channel == "TIME_SIGNATURE" then
			self.foregroundLayerData:setSignature(
				event.measure,
				ncdk.Fraction:new(event.value * 4, 32768, true)
			)
		elseif event.channel:find("NOTE") or event.channel:find("AUTO") then
			local timePoint = self.foregroundLayerData:getTimePoint(measureTime, -1)

			local noteData = ncdk.NoteData:new(timePoint)
			noteData.inputType = event.channel:find("NOTE") and "key" or "auto"
			noteData.inputIndex = event.channel:find("NOTE") and tonumber(event.channel:sub(-1, -1)) or 0

			if noteData.inputType == "auto" then
				noteData.noteType = "SoundNote"
				noteData.sounds = {{event.value, event.volume}}
				self.foregroundLayerData:addNoteData(noteData)
			else
				if event.measure > self.measureCount then
					self.measureCount = event.measure
				end
				if longNoteData[noteData.inputIndex] and event.type == "RELEASE" then
					longNoteData[noteData.inputIndex].noteType = "LongNoteStart"
					longNoteData[noteData.inputIndex].endNoteData = noteData
					noteData.startNoteData = longNoteData[noteData.inputIndex]
					noteData.noteType = "LongNoteEnd"
					longNoteData[noteData.inputIndex] = nil
					noteData.sounds = {}
				else
					noteData.noteType = "ShortNote"
					if event.type == "HOLD" then
						longNoteData[noteData.inputIndex] = noteData
					end

					self.noteCount = self.noteCount + 1
					noteData.sounds = {{event.value, event.volume}}
				end
				if not self.minTimePoint or timePoint < self.minTimePoint then
					self.minTimePoint = timePoint
				end
				if not self.maxTimePoint or timePoint > self.maxTimePoint then
					self.maxTimePoint = timePoint
				end
				self.foregroundLayerData:addNoteData(noteData)
			end
		end
	end

	if not self.tempoAtStart then
		self:addFirstTempo()
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
