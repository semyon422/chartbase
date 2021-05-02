local SM = {}

local SM_metatable = {}
SM_metatable.__index = SM

SM.new = function(self)
	local sm = {}

	sm.header = {}
	sm.bpm = {}
	sm.primaryTempo = 130

	self.measure = 0
	self.offset = 0
	self.mode = 0
	self.notes = {}
	self.linesPerMeasure = {}

	setmetatable(sm, SM_metatable)

	return sm
end

SM.import = function(self, noteChartString)
	for _, line in ipairs(noteChartString:split("\n")) do
		self:processLine(line:trim())
	end
end

SM.processLine = function(self, line)
	if self.parsingBpm then
		self:processBPM(line)
		if line:find(";") then
			self.parsingBpm = false
		end
		return
	end
	if line:find("^%d+$") then
		self:processNotesLine(line)
	elseif line:find("^,$") then
		self:processCommaLine()
	elseif line:find("#%S+:.*") then
		self:processHeaderLine(line)
	end
end

SM.processHeaderLine = function(self, line)
	local key, value = line:match("^#(%S+):(.*);$")
	if not key then
		key, value = line:match("^#(%S+):(.*)$")
	end
	key = key:upper()
	self.header[key] = value

	if key == "BPMS" then
		self:processBPM(value)
		if not line:find(";") then
			self.parsingBpm = true
		end
	end
end

SM.processBPM = function(self, line)
	local tempoValues = line:split(",")
	for _, tempoValue in ipairs(tempoValues) do
		local beat, tempo = tempoValue:match("^(.+)=(.+)$")
		if beat and tempo then
			-- print(beat, tempo, tonumber(beat), tonumber(tempo))
			table.insert(
				self.bpm,
				{
					beat = tonumber(beat),
					tempo = tonumber(tempo)
				}
			)
			return
		end
	end
end

SM.processCommaLine = function(self)
	self.measure = self.measure + 1
	self.offset = 0
end

SM.processNotesLine = function(self, line)
	self.mode = math.max(self.mode, #line)
	for i = 1, #line do
		local noteType = line:sub(i, i)
		if noteType == "1" then
			table.insert(
				self.notes,
				{
					measure = self.measure,
					offset = self.offset,
					noteType = noteType,
					inputIndex = i
				}
			)
		end
	end
	self.offset = self.offset + 1
	self.linesPerMeasure[self.measure] = (self.linesPerMeasure[self.measure] or 0) + 1
end

return SM
