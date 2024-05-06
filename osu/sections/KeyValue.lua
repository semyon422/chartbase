local Section = require("osu.sections.Section")

---@class osu.KeyValue: osu.Section
---@operator call: osu.KeyValue
---@field entries {[1]: string, [2]: string}[]
local KeyValue = Section + {}

KeyValue.space = false

---@param space boolean
function KeyValue:new(space)
	self.space = space
	self.entries = {}
end

---@param line string
function KeyValue:decodeLine(line)
	local key, value = line:match("^(%a+):%s?(.*)")
	if key then
		table.insert(self.entries, {key, value})
	end
end

---@return string[]
function KeyValue:encode()
	local out = {}

	local space = self.space and " " or ""
	for _, entry in ipairs(self.entries) do
		table.insert(out, ("%s:%s%s"):format(
			entry[1],
			space,
			entry[2]
		))
	end

	return out
end

return KeyValue
