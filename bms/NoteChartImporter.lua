local class = require("class")
local ncdk = require("ncdk")
local NoteChart = require("ncdk.NoteChart")
local Chartmeta = require("notechart.Chartmeta")
local enums = require("bms.enums")
local BMS = require("bms.BMS")
local EncodingConverter = require("notechart.EncodingConverter")
local dpairs = require("dpairs")

local bracketMatch = "%s(.+)%s$"
local brackets = {
	{"%[", "%]"},
	{"%(", "%)"},
	{"%-", "%-"},
	{"\"", "\""},
	{"〔", "〕"},
	{"‾", "‾"},
	{"~", "~"}
}

---@param name string
---@return string
---@return number
local function trimName(name)
	for i = 1, #brackets do
		local lb, rb = brackets[i][1], brackets[i][2]
		local start, _, _name = name:find(bracketMatch:format(lb, rb))
		if start then
			return _name, start
		end
	end
	return name, #name + 1
end

---@param title string
---@return string
---@return string
local function splitTitle(title)
	local name, bracketStart = trimName(title)
	return title:sub(1, bracketStart - 1), name
end

---@class bms.NoteChartImporter
---@operator call: bms.NoteChartImporter
local NoteChartImporter = class()

local encodings = {
	"SHIFT-JIS",
	"ISO-8859-1",
	"CP932",
	"EUC-KR",
	"US-ASCII",
	"CP1252",
}

function NoteChartImporter:new()
	self.conv = EncodingConverter(encodings)
end

function NoteChartImporter:import()
	self.noteChart = NoteChart()
	local noteChart = self.noteChart

	self.foregroundLayerData = noteChart:getLayerData(1)
	self.foregroundLayerData:setTimeMode("measure")
	self.foregroundLayerData:setSignatureMode("short")
	self.foregroundLayerData:setPrimaryTempo(130)

	if not self.bms then
		self.bms = BMS()
		self.bms.pms = self.path:lower():sub(-4, -1) == ".pms"
		local content = self.content:gsub("\r[\r\n]?", "\n")
		content = self.conv:convert(content)
		self.bms:import(content)
	end

	self:setInputMode()
	self:addFirstTempo()
	self:processData()
	self:processMeasureLines()

	noteChart.type = "bms"
	noteChart:compute()

	self:updateLength()

	local bms = self.bms
	local header = bms.header
	local title, name = splitTitle(header["TITLE"])
	noteChart.chartmeta = Chartmeta({
		format = "bms",
		title = title,
		artist = header["ARTIST"],
		name = name,
		level = tonumber(header["PLAYLEVEL"]),
		stage_path = header["STAGEFILE"],
		notes_count = self.notes_count,
		duration = self.totalLength,
		tempo = bms.baseTempo or 0,
		inputmode = tostring(noteChart.inputMode),
		start_time = self.minTime,
	})

	self.noteCharts = {noteChart}
end

function NoteChartImporter:setInputMode()
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

function NoteChartImporter:updateLength()
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

---@param timeData table
function NoteChartImporter:setTempo(timeData)
	if not timeData[enums.BackChannelEnum["Tempo"]] then
		return
	end
	local tempo = tonumber(timeData[enums.BackChannelEnum["Tempo"]][1], 16)
	local ld = self.foregroundLayerData
	ld:insertTempoData(timeData.measureTime, tempo)
end

---@param timeData table
---@return boolean?
function NoteChartImporter:setExtendedTempo(timeData)
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

---@param timeData table
function NoteChartImporter:setStop(timeData)
	if not timeData[enums.BackChannelEnum["Stop"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["Stop"]][1]
	local duration = self.bms.stop[value]
	if not duration then
		return
	end

	local ld = self.foregroundLayerData

	-- beatDuration = STOP * 4 / 192
	local beatDuration = ncdk.Fraction(duration * 4, 16, false) / 192

	ld:insertStopData(timeData.measureTime, beatDuration)
end

function NoteChartImporter:processData()
	local longNoteData = {}

	self.notes_count = 0

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
					local timePoint = self.foregroundLayerData:getTimePoint(timeData.measureTime)

					local noteData = ncdk.NoteData(timePoint)

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
					self.foregroundLayerData:addNoteData(noteData, channelInfo.inputType, channelInfo.inputIndex)

					if
						channelInfo.inputType ~= "auto" and
						not channelInfo.mine and
						channelInfo.name ~= "BGA"
					then
						if noteData.noteType ~= "LongNoteEnd" then
							self.notes_count = self.notes_count + 1
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

function NoteChartImporter:processMeasureLines()
	for measureIndex = 0, self.bms.measureCount do
		local measureTime = ncdk.Fraction(measureIndex)
		local timePoint = self.foregroundLayerData:getTimePoint(measureTime)

		local startNoteData = ncdk.NoteData(timePoint)
		startNoteData.noteType = "LineNoteStart"
		self.foregroundLayerData:addNoteData(startNoteData, "measure", 1)

		local endNoteData = ncdk.NoteData(timePoint)
		endNoteData.noteType = "LineNoteEnd"
		self.foregroundLayerData:addNoteData(endNoteData, "measure", 1)

		startNoteData.endNoteData = endNoteData
		endNoteData.startNoteData = startNoteData
	end
end

function NoteChartImporter:addFirstTempo()
	if not self.bms.tempoAtStart and self.bms.baseTempo then
		local measureTime = ncdk.Fraction(0)
		local ld = self.foregroundLayerData

		ld:insertTempoData(measureTime, self.bms.baseTempo)
	end
end

return NoteChartImporter
