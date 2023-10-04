local keys_and_types = {
	string = {
		"format",
		"title",
		"artist",
		"source",
		"tags",
		"name",
		"creator",
		"audioPath",
		"stagePath",
		"inputMode",
	},
	number = {
		"index",
		"level",
		"previewTime",
		"noteCount",
		"length",
		"bpm",
		"minTime",
		"maxTime",
		"avgTempo",
		"minTempo",
		"maxTempo",
	}
}

local required_keys = {
	"inputMode",
}

local default_values = {
	index = 1,
}

local allowed_keys = {}
for _type, keys in pairs(keys_and_types) do
	for _, key in ipairs(keys) do
		allowed_keys[key] = _type
	end
end

---@param t table
---@param k string
local function assert_type(t, k)
	local exp_type = allowed_keys[k]
	local _type = type(t[k])
	assert(_type == exp_type, ("bad key '%s' (%s expected, got %s)"):format(k, exp_type, _type))
end

---@param t table
---@return table
local function UnifiedMetaData(t)
	for k in pairs(t) do
		assert(allowed_keys[k], ("key '%s' not allowed"):format(k))
		assert_type(t, k)
	end
	for _, k in pairs(required_keys) do
		assert(t[k], ("key '%s' required"):format(k))
		assert_type(t, k)
	end
	for k, v in pairs(default_values) do
		t[k] = t[k] or v
	end
	return t
end

return UnifiedMetaData
