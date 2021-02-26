local iconv = require("iconv")
local validate = require("aqua.utf8").validate

local EncodingConverter = {}

local Encodings = {
	{"UTF-8", "SHIFT-JIS"},
	{"UTF-8", "CP932"},
	{"UTF-8", "EUC-KR"},
	{"UTF-8", "US-ASCII"},
	{"UTF-8", "CP1252"},
	{"UTF-8//IGNORE", "SHIFT-JIS"},
}

EncodingConverter.init = function(self)
    if self.inited then
        return
    end

	local conversionDescriptors = {}
	self.conversionDescriptors = conversionDescriptors
	
	for i, tofrom in ipairs(Encodings) do
		conversionDescriptors[i] = iconv:open(tofrom[1], tofrom[2])
    end
    
    self.inited = true
end

EncodingConverter.fix = function(self, line)
    self:init()

	if not line then
		return ""
	elseif validate(line) == line then
		return line
	else
		local validLine
		for i, cd in ipairs(self.conversionDescriptors) do
			validLine = cd:convert(line)
			if validLine then break end
		end
		validLine = validLine or "<conversion error>"
		return validate(validLine)
	end
end

return EncodingConverter
