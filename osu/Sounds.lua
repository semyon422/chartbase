local class = require("class")

---@class osu.Sound
---@field [1] string name
---@field [2] number volume

---@class osu.Sounds
---@operator call: osu.Sounds
local Sounds = class()

local soundBits = {
	{2, "whistle"},
	{4, "finish"},
	{8, "clap"},
	{0, "normal"}
}

local SampleSet = {
	[0] = "none",
	[1] = "normal",
	[2] = "soft",
	[3] = "drum",
}

---@param id number
---@return string
function Sounds:getSampleSetName(id)
	return SampleSet[id] or "normal"
end

---@param soundType number
---@param addition osu.Addition
---@param point osu.ControlPoint
function Sounds:decode(soundType, addition, point)
	local real_volume = 0

	if addition.volume > 0 then
		real_volume = addition.volume
	elseif point.volume > 0 then
		real_volume = point.volume
	elseif addition.sampleFile and addition.sampleFile ~= "" then
		real_volume = 100
	else
		real_volume = 5
	end

	---@type osu.Sound[]
	local real_sounds = {}
	---@type osu.Sound[]
	local fallback_sounds = {}

	local is_keysound = false

	if addition.sampleFile and addition.sampleFile ~= "" then
		real_sounds[1] = {addition.sampleFile, real_volume}
		fallback_sounds[1] = {addition.sampleFile, real_volume}
		is_keysound = true
		return
	end

	local sampleSetId = 0
	if soundType > 0 and addition.addSampleSet ~= 0 then
		sampleSetId = addition.addSampleSet
	elseif addition.sampleSet ~= 0 then
		sampleSetId = addition.sampleSet
	else
		sampleSetId = point.sampleSet
	end

	local sampleSetName = self:getSampleSetName(sampleSetId)
	local postfix = ""

	if addition.customSample ~= 0 then
		postfix = addition.customSample
	elseif point.customSamples ~= 0 then
		postfix = point.customSamples
	end

	for i, d in ipairs(soundBits) do
		local mask = d[1]
		local name = d[2]
		if
			i < 4 and bit.band(soundType, mask) == mask or
			i == 4 and #real_sounds == 0
		then
			table.insert(real_sounds, {sampleSetName .. "-hit" .. name .. postfix, real_volume})
			table.insert(fallback_sounds, {sampleSetName .. "-hit" .. name, real_volume})
		end
	end

	return real_sounds
end

return Sounds
