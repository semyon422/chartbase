local ncdk = require("ncdk")
local enums = require("bms.enums")

local BMS = {}

local BMS_metatable = {}
BMS_metatable.__index = BMS

BMS.new = function(self)
	local bms = {}
	
	bms.header = {}
	bms.wav = {}
	bms.bpm = {}
	bms.bmp = {}
	bms.stop = {}
	bms.signature = {}

	bms.inputExisting = {}
	bms.channelExisting = {}
	
	bms.timePointLimit = 25000
	bms.timePointCount = 0

	bms.primaryTempo = 130
	bms.measureCount = 0
	bms.hasTempo = false
	
	bms.timePoints = {}
	bms.timeList = {}
	
	setmetatable(bms, BMS_metatable)
	
	return bms
end

BMS.import = function(self, noteChartString)
	for _, line in ipairs(noteChartString:split("\n")) do
		self:processLine(line:trim())
	end

	if not self.hasTempo then
		self.baseTempo = self.primaryTempo
	end
	
	for _, timeData in pairs(self.timePoints) do
		table.insert(self.timeList, timeData)
	end
	
	table.sort(self.timeList, function(a, b)
		return a.measureTime < b.measureTime
	end)

	self:detectKeymode()
end

BMS.processLine = function(self, line)
	if line:upper():find("^#WAV%S%S%s+.+$") then
		local index, fileName = line:match("^#...(..)%s+(.+)$")
		self.wav[index:upper()] = fileName
	elseif line:upper():find("^#BPM%S%S%s+.+$") then
		local index, tempo = line:match("^#...(..)%s+(.+)$")
		self.bpm[index:upper()] = tonumber(tempo)
	elseif line:upper():find("^#BMP%S%S%s+.+$") then
		local index, path = line:match("^#...(..)%s+(.+)$")
		self.bmp[index:upper()] = path
	elseif line:upper():find("^#STOP%S%S%s+.+$") then
		local index, duration = line:match("^#....(..)%s+(.+)$")
		self.stop[index:upper()] = tonumber(duration)
	elseif line:find("^#%d%d%d%S%S:.+$") then
		self:processLineData(line)
	elseif line:find("^#%S+%s+.+$") then
		self:processHeaderLine(line)
	end
end

BMS.processHeaderLine = function(self, line)
	local key, value = line:match("^#(%S+)%s+(.+)$")
	key = key:upper()
	self.header[key] = value
	
	if key == "BPM" then
		self.baseTempo = tonumber(value)
		self.hasTempo = true
	elseif key == "LNOBJ" then
		self.lnobj = value
	end
end

BMS.detectKeymode = function(self)
	local ce = self.channelExisting

	if not self.pms then
		if ce["28"] or ce["29"] then
			self.mode = 14
			return
		elseif ce["21"] or ce["22"] or ce["23"] or ce["24"] or ce["25"] then
			if ce["18"] or ce["19"] then
				self.mode = 14
				return
			end
			self.mode = 10
			return
		elseif ce["18"] or ce["19"] then
			if ce["26"] then
				self.mode = 27
				return
			end
			self.mode = 7
			return
		elseif ce["11"] or ce["12"] or ce["13"] or ce["14"] or ce["15"] then
			if ce["26"] then
				self.mode = 25
				return
			end
			self.mode = 5
			return
		elseif ce["16"] then
			if ce["26"] then
				self.mode = 14
				return
			end
			self.mode = 7
			return
		end
	elseif ce["24"] or ce["25"] then
		self.mode = 59
		return
	elseif ce["23"] or ce["13"] or ce["14"] or ce["15"] or ce["22"] then
		if ce["11"] or ce["12"] then
			self.mode = 59
			return
		end
		self.mode = 55
		return
	elseif ce["11"] or ce["12"] then
		self.mode = 59
		return
	end
end

BMS.updateMode = function(self, channel)
	local channelExisting = self.channelExisting

    local channelInfo = enums.ChannelEnum[channel]
    if channelInfo and channelInfo.name == "Note" then
        channelExisting[channelInfo.channelBase] = true
	end
end

BMS.processLineData = function(self, line)
	if self.timePointCount >= self.timePointLimit then
		return
	end

	local measure, channel, message = line:match("^#(...)(..):(.+)$")
	measure = tonumber(measure)
	
	if measure > self.measureCount then
		self.measureCount = measure
	end
	
	if not enums.ChannelEnum[channel] then
		return
	end
	
	self:updateMode(channel)
	
	if enums.ChannelEnum[channel].name == "Signature" then
		self.signature[measure] = tonumber((message:gsub(",", ".")))
		return
	end
	
	if
		(enums.ChannelEnum[channel].name == "Tempo" or
		enums.ChannelEnum[channel].name == "ExtendedTempo") and
		measure == 0 and
		message:sub(1, 2) ~= "00"
	then
		self.tempoAtStart = true
		self.hasTempo = true
	end
	
	local compound = enums.ChannelEnum[channel].name ~= "BGM"
	local messageLength = math.floor(#message / 2)
	for i = 1, messageLength do
		local value = message:sub(2 * i - 1, 2 * i)
		if value ~= "00" then
			local measureTime = ncdk.Fraction:new(i - 1, messageLength) + measure
			local measureTimeString = tostring(measureTime)
			
			local timeData
			if self.timePoints[measureTimeString] then
				timeData = self.timePoints[measureTimeString]
			else
				timeData = {}
				timeData.measureTime = measureTime
				self.timePoints[measureTimeString] = timeData

				self.timePointCount = self.timePointCount + 1
			end
			
			local settedNoteChannel
			for currentChannel, values in pairs(timeData) do
				if
					enums.ChannelEnum[currentChannel] and
					enums.ChannelEnum[currentChannel].name == "Note" and
					enums.ChannelEnum[channel].inputType == enums.ChannelEnum[currentChannel].inputType and
					enums.ChannelEnum[channel].inputIndex == enums.ChannelEnum[currentChannel].inputIndex
				then
					settedNoteChannel = currentChannel -- may differs from channel due to different channels for long notes
					break
				end
			end
			
			timeData[channel] = timeData[channel] or {}
			if compound then
				if enums.ChannelEnum[channel].name == "Note" then
					if enums.ChannelEnum[channel].long then
						if settedNoteChannel then
							timeData[settedNoteChannel][1] = nil
							timeData[settedNoteChannel] = nil
						end
						timeData[channel] = timeData[channel] or {}
						timeData[channel][1] = value
					end
					if not enums.ChannelEnum[channel].long and not settedNoteChannel then
						timeData[channel][1] = value
					end
				else
					timeData[channel][1] = value
					if enums.ChannelEnum[channel].name == "Tempo" or
						enums.ChannelEnum[channel].name == "ExtendedTempo"
					then
						self.hasTempo = true
					end
				end
			else
				table.insert(timeData[channel], value)
			end
		end
	end
end

return BMS
