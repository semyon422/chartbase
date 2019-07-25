local Ksh = {}

local Ksh_metatable = {}
Ksh_metatable.__index = Ksh

Ksh.laserPosString = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmno"
Ksh.laserPosTable = {}
for i = 1, 51 do
	Ksh.laserPosTable[Ksh.laserPosString:sub(i, i)] = i - 1
end

Ksh.new = function(self)
	local ksh = {}
	
	ksh.notes = {}
	ksh.lasers = {}
	ksh.tempos = {}
	ksh.timeSignatures = {}
	ksh.options = {}
	ksh.measureLineCounts = {}
	ksh.preparedNotes = {}
	ksh.preparedLasers = {}
	
	setmetatable(ksh, Ksh_metatable)
	
	return ksh
end

Ksh.import = function(self, noteChartString)
	self.noteChartString = noteChartString
	
	self.measureStrings = noteChartString:split("\n--\n", true)
	self.measureStrings[#self.measureStrings + 1] = "0000|00|--"
	
	for measureIndex = 1, #self.measureStrings - 1 do
		local measureString = self.measureStrings[measureIndex + 1]
		self.measureLineCounts[measureIndex] = 0
		for _, line in ipairs(measureString:split("\n")) do
			if line:sub(1, 1) ~= "#" and line:sub(1, 2) ~= '//' and line:sub(8, 8) == "|" and not line:find("=") then
				self.measureLineCounts[measureIndex] = self.measureLineCounts[measureIndex] + 1
			end
			if self.measureLineCounts[measureIndex] == 0 then
				self.measureLineCounts[measureIndex] = 1
			end
		end
	end
	
	for measureIndex = 0, #self.measureStrings - 1 do
		local measureString = self.measureStrings[measureIndex + 1]
		local lineOffset = 0
		
		for _, line in ipairs(measureString:split("\n")) do
			local key, value = line:match("^(.-)=(.*)$")
			
			if key then
				if not self.options[key] then
					self.options[key] = value
				end
				
				if key == "t" then
					if not value:find("-") then
						local lastTempo = self.tempos[#self.tempos]
						local newTempo = {
							measureOffset = measureIndex - 1,
							lineOffset = lineOffset,
							lineCount = self.measureLineCounts[measureIndex],
							tempo = tonumber(value)
						}
						if lastTempo and (
							lastTempo.measureOffset == newTempo.measureOffset and
							lastTempo.lineOffset == newTempo.lineOffset
						) then
							self.tempos[#self.tempos] = newTempo
						else
							self.tempos[#self.tempos + 1] = newTempo
						end
					end
				elseif key == "beat" then
					local values = value:split("/")
					if #values == 2 then
						self.timeSignatures[#self.timeSignatures + 1] = {
							measureIndex = measureIndex - 1,
							n = tonumber(values[1]),
							d = tonumber(values[2])
						}
					end
				end
			elseif line:sub(1, 1) ~= "#" and line:sub(1, 2) ~= '//' and line:sub(8, 8) == "|" then
				local chars = {}
				for i = 1, #line do chars[i] = line:sub(i, i) end
				
				for i = 1, 6 do
					local c, chipChar, input
					
					if i <= 4 then
						c = chars[i]
						chipChar = "1"
						input = "bt"
					else
						c = chars[i + 1]
						chipChar = "2"
						input = "fx"
					end
					
					if c == "0" then
						local note = self.preparedNotes[i]
						if note then
							note.endMeasureOffset = measureIndex - 1
							note.endLineOffset = lineOffset
							note.endLineCount = self.measureLineCounts[measureIndex]
							
							self.notes[#self.notes + 1] = note
							self.preparedNotes[i] = nil
						end
					elseif c == chipChar then
						self.notes[#self.notes + 1] = {
							startMeasureOffset = measureIndex - 1,
							startLineOffset = lineOffset,
							startLineCount = self.measureLineCounts[measureIndex],
							endMeasureOffset = measureIndex - 1,
							endLineOffset = lineOffset,
							endLineCount = self.measureLineCounts[measureIndex],
							lane = i,
							input = input
						}
					else
						local note = self.preparedNotes[i]
						if not note then
							self.preparedNotes[i] = {
								startMeasureOffset = measureIndex - 1,
								startLineOffset = lineOffset,
								startLineCount = self.measureLineCounts[measureIndex],
								lane = i,
								input = input
							}
						end
					end
				end
				
				for i = 1, 2 do
					local c = chars[i + 8]
					local laser = self.preparedLasers[i]
					
					if c == ":" then
						-- skip
					elseif self.laserPosTable[c] then
						if laser then
							laser.posEnd = self.laserPosTable[c]
							laser.endMeasureOffset = measureIndex - 1
							laser.endLineOffset = lineOffset
							laser.endLineCount = self.measureLineCounts[measureIndex]
							
							self.lasers[#self.lasers + 1] = laser
						end
						
						self.preparedLasers[i] = {
							startMeasureOffset = measureIndex - 1,
							startLineOffset = lineOffset,
							startLineCount = self.measureLineCounts[measureIndex],
							lane = i,
							posStart = self.laserPosTable[c],
							input = "laser"
						}
					else
						self.preparedLasers[i] = nil
					end
				end
				
				lineOffset = lineOffset + 1
			end
		end
	end
end

return Ksh
