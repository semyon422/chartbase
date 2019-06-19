local TinyParser = {}

local TinyParser_metatable = {}
TinyParser_metatable.__index = TinyParser

TinyParser.new = function(self)
	local osu = {}
	
	osu.notes = {}
	
	setmetatable(osu, TinyParser_metatable)
	
	return osu
end

TinyParser.import = function(self, noteChartString)
	local block
	for _, line in ipairs(noteChartString:split("\n")) do
		if line:find("^%[") then
			block = line:match("^%[(.+)%]")
		else
			if line:find("^%a+:.*$") then
				local key, value = line:match("^(%a+):%s?(.*)")
				if key == "CircleSize" then
					self.columnCount = tonumber(value)
				end
			elseif block == "HitObjects" and line ~= "" then
				local note = {}
				local data = line:split(",")
				note.column = math.min(math.max(math.ceil(tonumber(data[1]) / 512 * self.columnCount), 1), self.columnCount)
				
				note.startTime = tonumber(data[3])
				if bit.band(tonumber(data[4]), 128) == 128 then
					local addition = data[6]:split(":")
					note.endTime = tonumber(addition[1])
				end
				
				table.insert(self.notes, note)
			end
		end
	end
end

return TinyParser
