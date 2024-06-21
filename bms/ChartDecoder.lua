local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Bms = require("bms.BMS")
local Note = require("notechart.Note")
local Signature = require("ncdk2.to.Signature")
local Tempo = require("ncdk2.to.Tempo")
local Stop = require("ncdk2.to.Stop")
local MeasureLayer = require("ncdk2.layers.MeasureLayer")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Chartmeta = require("notechart.Chartmeta")
local EncodingConverter = require("notechart.EncodingConverter")
local enums = require("bms.enums")
local BMS = require("bms.BMS")
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

---@class bms.ChartDecoder: chartbase.IChartDecoder
---@operator call: bms.ChartDecoder
local ChartDecoder = IChartDecoder + {}

local encodings = {
	"SHIFT-JIS",
	"ISO-8859-1",
	"CP932",
	"EUC-KR",
	"US-ASCII",
	"CP1252",
}

function ChartDecoder:new()
	self.conv = EncodingConverter(encodings)
end

---@param s string
---@return ncdk2.Chart[]
function ChartDecoder:decode(s)
	local bms = Bms()
	local content = s:gsub("\r[\r\n]?", "\n")
	content = self.conv:convert(content)
	bms:import(content)
	local chart = self:decodeBms(bms)
	return {chart}
end

---@param bms bms.BMS
---@return ncdk2.Chart
function ChartDecoder:decodeBms(bms)
	self.bms = bms

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	self:setInputMode()
	self:addFirstTempo()
	self:processData()
	self:processMeasureLines()

	chart.type = "bms"
	chart:compute()

	self:updateLength()
	self:setMetadata()

	return chart
end

function ChartDecoder:updateLength()
	if self.maxPoint and self.minPoint then
		self.totalLength = self.maxPoint.absoluteTime - self.minPoint.absoluteTime
		self.minTime = self.minPoint.absoluteTime
		self.maxTime = self.maxPoint.absoluteTime
	else
		self.totalLength = 0
		self.minTime = 0
		self.maxTime = 0
	end
end

function ChartDecoder:setMetadata()
	local bms = self.bms
	local header = bms.header
	local title, name = splitTitle(header["TITLE"])
	self.chart.chartmeta = Chartmeta({
		format = "bms",
		title = title,
		artist = header["ARTIST"],
		name = name,
		level = tonumber(header["PLAYLEVEL"]),
		stage_path = header["STAGEFILE"],
		notes_count = self.notes_count,
		duration = self.totalLength,
		tempo = bms.baseTempo or 0,
		inputmode = tostring(self.chart.inputMode),
		start_time = self.minTime,
	})
end

function ChartDecoder:setInputMode()
	local mode = self.bms.mode
	local inputMode = self.chart.inputMode
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

function ChartDecoder:addFirstTempo()
	if not self.bms.tempoAtStart and self.bms.baseTempo then
		local point = self.layer:getPoint(Fraction(0))
		point._tempo = Tempo(self.bms.baseTempo)
	end
end

---@param timeData table
function ChartDecoder:setTempo(timeData)
	if not timeData[enums.BackChannelEnum["Tempo"]] then
		return
	end
	local tempo = tonumber(timeData[enums.BackChannelEnum["Tempo"]][1], 16)
	local point = self.layer:getPoint(timeData.measureTime)
	point._tempo = Tempo(tempo)
end

---@param timeData table
---@return boolean?
function ChartDecoder:setExtendedTempo(timeData)
	if not timeData[enums.BackChannelEnum["ExtendedTempo"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["ExtendedTempo"]][1]
	local tempo = self.bms.bpm[value]
	if not tempo then
		return
	end

	local point = self.layer:getPoint(timeData.measureTime)
	point._tempo = Tempo(tempo)

	return true
end

---@param timeData table
function ChartDecoder:setStop(timeData)
	if not timeData[enums.BackChannelEnum["Stop"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["Stop"]][1]
	local duration = self.bms.stop[value]
	if not duration then
		return
	end


	-- beatDuration = STOP * 4 / 192
	local point = self.layer:getPoint(timeData.measureTime)
	point._stop = Stop(Fraction(duration * 4, 16, false) / 192)

	self.layer:getPoint(timeData.measureTime, true)
end

function ChartDecoder:processData()
	local longNoteData = {}

	self.notes_count = 0

	self.minPoint = nil
	self.maxPoint = nil

	local layer = self.layer

	for measureIndex, value in pairs(self.bms.signature) do
		local point = layer:getPoint(Fraction(measureIndex))
		point._signature = Signature(Fraction(value * 4, 32768, true))
		local next_point = layer:getPoint(Fraction(measureIndex + 1))
		if not next_point._signature then
			next_point._signature = Signature()
		end
	end

	for _, timeData in ipairs(self.bms.timeList) do
		if not self:setExtendedTempo(timeData) then
			self:setTempo(timeData)
		end
		self:setStop(timeData)

		local point = layer:getPoint(timeData.measureTime)

		for channelIndex, indexDataValues in dpairs(timeData) do
			local channelInfo = self.ChannelEnum[channelIndex] or enums.ChannelEnum[channelIndex]

			if channelInfo and (
				channelInfo.name == "Note" and channelInfo.invisible ~= true or
				channelInfo.name == "BGM" or
				channelInfo.name == "BGA"
			)
			then
				for _, value in ipairs(indexDataValues) do
					local visualPoint = layer.visual:getPoint(point)
					local note = Note(visualPoint)

					note.sounds = {}
					note.images = {}
					if channelInfo.name == "Note" or channelInfo.name == "BGM" then
						local sound = self.bms.wav[value]
						if sound and not channelInfo.mine then
							note.sounds[1] = {sound, 1}
							self.chart.resourceList:add("sound", sound, {sound})
						end
					elseif channelInfo.name == "BGA" then
						local image = self.bms.bmp[value]
						if image then
							note.images[1] = {image, 1}
							self.chart.resourceList:add("image", image, {image})
						end
					end

					if channelInfo.name == "BGA" then
						note.noteType = "ImageNote"
					elseif channelInfo.inputType == "auto" or channelInfo.mine then
						note.noteType = "SoundNote"
					elseif channelInfo.long then
						if not longNoteData[channelIndex] then
							note.noteType = "LongNoteStart"
							longNoteData[channelIndex] = note
						else
							note.noteType = "LongNoteEnd"
							note.sounds = {}
							note.startNote = longNoteData[channelIndex]
							longNoteData[channelIndex].endNote = note
							longNoteData[channelIndex] = nil
						end
					else
						if longNoteData[channelIndex] and value == self.bms.lnobj then
							longNoteData[channelIndex].noteType = "LongNoteStart"
							longNoteData[channelIndex].endNote = note
							note.startNote = longNoteData[channelIndex]
							note.noteType = "LongNoteEnd"
							note.sounds = {}
							longNoteData[channelIndex] = nil
						else
							note.noteType = "ShortNote"
							longNoteData[channelIndex] = note
						end
					end
					layer.notes:insert(note, channelInfo.inputType .. channelInfo.inputIndex)

					if
						channelInfo.inputType ~= "auto" and
						not channelInfo.mine and
						channelInfo.name ~= "BGA"
					then
						if note.noteType ~= "LongNoteEnd" then
							self.notes_count = self.notes_count + 1
						end

						if not self.minPoint or point < self.minPoint then
							self.minPoint = point
						end

						if not self.maxPoint or point > self.maxPoint then
							self.maxPoint = point
						end
					end
				end
			end
		end
	end
	for _, note in pairs(longNoteData) do
		note.noteType = "ShortNote"
	end
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	for measureIndex = 0, self.bms.measureCount do
		local point = layer:getPoint(Fraction(measureIndex))

		local startNote = Note(layer.visual:getPoint(point))
		startNote.noteType = "LineNoteStart"
		layer.notes:insert(startNote, "measure1")

		local endNote = Note(layer.visual:newPoint(point))
		endNote.noteType = "LineNoteEnd"
		layer.notes:insert(endNote, "measure1")

		startNote.endNote = endNote
		endNote.startNote = startNote
	end
end

return ChartDecoder
