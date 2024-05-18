local class = require("class")
local bit = require("bit")
local table_util = require("table_util")

---@class osu.Sound
---@field name string
---@field fallback_name string?
---@field volume number

---@class osu.Sounds
---@operator call: osu.Sounds
local Sounds = class()

local SoundType = {
	None = 0,
	Normal = 1,
	Whistle = 2,
	Finish = 4,
	Clap = 8,
}

local SampleSet = {
	None = 0,
	Normal = 1,
	Soft = 2,
	Drum = 3,
}

local SoundVolume = {
	Normal = 0.8,
	Whistle = 0.85,
	Finish = 1,
	Clap = 0.85,
}

local SoundOrder = {
	"Normal",
	"Finish",
	"Whistle",
	"Clap",
}

local function is_type(_type, v)
	return bit.band(_type, v) ~= 0
end

---@param id number
---@return string
function Sounds:getSampleSetName(id)
	return SampleSet[id] or "normal"
end

---@param soundType number
---@param sampleSet number
---@param customSampleSet number
---@param is_taiko boolean?
---@return string
---@return string?
function Sounds:getSampleName(soundType, sampleSet, customSampleSet, is_taiko)
	---@type string
	local strSoundType = table_util.keyof(SoundType, soundType):lower()

	if sampleSet == SampleSet.None then
		sampleSet = SampleSet.Soft
	end
	---@type string
	local strSampleSet = table_util.keyof(SampleSet, sampleSet):lower()
	local customSample = math.max(customSampleSet, 0)
	local modePrefix = is_taiko and "taiko-" or ""

	local name = ("%s%s-hit%s"):format(
		modePrefix,
		strSampleSet,
		strSoundType
	)
	if customSample == 0 then
		return name
	end

	return name .. customSample, name
end

---@param soundType number
---@param addition osu.Addition
---@param point osu.ControlPoint
---@return osu.Sound[]
---@return boolean
function Sounds:decode(soundType, addition, point)
	local real_volume = 100
	if addition.volume > 0 then
		real_volume = addition.volume
	elseif point.volume > 0 then
		real_volume = point.volume
	end
	real_volume = math.max(real_volume, 8)

	---@type osu.Sound[]
	local real_sounds = {}

	if addition.sampleFile and addition.sampleFile ~= "" then
		real_sounds[1] = {
			name = addition.sampleFile,
			volume = real_volume,
		}
		return real_sounds, true
	end

	local sampleSetId = 0
	if addition.addSampleSet ~= 0 then
		sampleSetId = addition.addSampleSet
	elseif addition.sampleSet ~= 0 then
		sampleSetId = addition.sampleSet
	else
		sampleSetId = point.sampleSet
	end

	local customSample = 0
	if addition.customSample ~= 0 then
		customSample = addition.customSample
	elseif point.customSamples ~= 0 then
		customSample = point.customSamples
	end

	for _, name in ipairs(SoundOrder) do
		local Type = SoundType[name]
		if is_type(Type, soundType) then
			local _name, fallback_name = self:getSampleName(Type, sampleSetId, customSample)
			table.insert(real_sounds, {
				name = _name,
				fallback_name = fallback_name,
				volume = real_volume * SoundVolume[name],
			})
		end
	end

	if #real_sounds == 0 then
		local _name, fallback_name = self:getSampleName(SoundType.Normal, sampleSetId, customSample)
		table.insert(real_sounds, {
			name = _name,
			fallback_name = fallback_name,
			volume = real_volume * SoundVolume.Normal,
		})
	end

	return real_sounds, false
end

return Sounds
