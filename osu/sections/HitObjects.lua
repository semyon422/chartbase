local Section = require("osu.sections.Section")
local bit = require("bit")

---@class osu.HitObject
---@field x number
---@field y number
---@field time number
---@field endTime number?
---@field type number
---@field soundType number
---@field repeatCount number?
---@field length number?
---@field curveType string?
---@field points osu.Vector2[]?
---@field sounds number[]?
---@field ss number[]?
---@field ssa number[]?
---@field sampleSet number
---@field addSampleSet number
---@field customSample number
---@field volume number
---@field sampleFile string

---@alias osu.Vector2 number[]

---@class osu.HitObjects: osu.Section
---@operator call: osu.HitObjects
---@field objects osu.HitObject[]
local HitObjects = Section + {}

local HitObjectType = {
	Normal = 1,
	Slider = 2,
	NewCombo = 4,
	NormalNewCombo = 5,
	SliderNewCombo = 6,
	Spinner = 8,
	ColourHax = 112,
	Hold = 128,
	ManiaLong = 128,
}

local function is_type(_type, v)
	return bit.band(_type, v) ~= 0
end

function HitObjects:new()
	self.objects = {}
end

---@param object osu.HitObject
---@param s string
---@param hold boolean?
local function parse_addition(object, s, hold)
	if not s or #s == 0 then
		return
	end
	local addition = s:split(":")
	local offset = hold and 1 or 0
	if hold then
		object.endTime = tonumber(addition[1]) or object.time
	end
	object.sampleSet = tonumber(addition[1 + offset]) or 0
	object.addSampleSet = tonumber(addition[2 + offset]) or 0
	object.customSample = tonumber(addition[3 + offset]) or 0
	object.volume = tonumber(addition[4 + offset]) or 0
	object.sampleFile = addition[5 + offset] or ""
end

---@param object osu.HitObject
---@param split string[]
---@param soundType number
local function decode_osu_slider(object, split, soundType)
	local curveType = "C"
	local repeatCount = 0
	local length = 0

	---@type osu.Vector2[]
	local points = {}

	---@type number[]
	local sounds = nil

	---@type string[]
	local pointsplit = split[6]:split("|")
	for i = 1, #pointsplit do
		local point = pointsplit[i]
		if #point == 1 then
			curveType = point
			goto continue
		end

		---@type string[]
		local temp = point:split(":")

		---@type osu.Vector2
		local v = {tonumber(temp[1]), tonumber(temp[2])}
		table.insert(points, v)

		::continue::
	end

	object.curveType = curveType

	repeatCount = tonumber(split[7])
	assert(repeatCount <= 9000, "too many repeats")
	object.repeatCount = repeatCount

	if #split > 7 then
		length = tonumber(split[8])
	end
	if #split > 8 and #split[9] > 0 then
		---@type string[]
		local adds = split[9]:split("|")
		if #adds > 0 then
			sounds = {}
			local addslength = math.min(#adds, repeatCount + 1)
			for i = 1, addslength do
				table.insert(sounds, tonumber(adds[i]))
			end
			for i = addslength + 1, repeatCount + 1 do
				table.insert(sounds, soundType)
			end
		end
	end

	---@type number[]
	local ss = {}
	---@type number[]
	local ssa = {}

	if #split > 9 and #split[10] > 0 then
		---@type string[]
		local sets = split[10]:split("|")
		if #sets > 0 then
			for _, t in ipairs(sets) do
				---@type string[]
				local split2 = t:split(":")
				table.insert(ss, tonumber(split2[1]))
				table.insert(ssa, tonumber(split2[2]))
			end
		end
	end

	if sounds then
		if #ss > repeatCount + 1 then
			for i = repeatCount + 1, repeatCount + 1 + #ss - repeatCount - 1 do
				ss[i + 1] = nil
			end
		else
			for z = #ss, repeatCount do
				table.insert(ss, 0)
			end
		end
		if #ssa > repeatCount + 1 then
			for i = repeatCount + 1, repeatCount + 1 + #ss - repeatCount - 1 do
				ssa[i + 1] = nil
			end
		else
			for z = #ssa, repeatCount do
				table.insert(ssa, 0)
			end
		end
	end

	if #split > 10 then
		parse_addition(object, split[11])
	end

	object.points = points
	object.sounds = sounds
	object.length = length
	object.ss = ss
	object.ssa = ssa
end

---@param line string
function HitObjects:decodeLine(line)
	---@type string[]
	local split = line:split(",")

	local object = {
		sampleSet = 0,
		addSampleSet = 0,
		customSample = 0,
		volume = 0,
	}
	---@cast object osu.HitObject

	object.x = math.min(math.max(tonumber(split[1]) or 0, 0), 512)
	object.y = math.min(math.max(tonumber(split[2]) or 0, 0), 512)
	object.time = tonumber(split[3]) or 0

	local _type = bit.band(tonumber(split[4]) or 0, bit.bnot(HitObjectType.ColourHax))
	object.type = _type
	object.soundType = tonumber(split[5]) or 0

	if is_type(HitObjectType.Normal, _type) then
		parse_addition(object, split[6])
	elseif is_type(HitObjectType.Slider, _type) then
		local length = tonumber(split[8])
		object.endTime = length and object.time + length or object.time
		decode_osu_slider(object, split, object.soundType)
	elseif is_type(HitObjectType.Spinner, _type) then
		object.endTime = tonumber(split[6])
		parse_addition(object, split[7])
	elseif is_type(HitObjectType.Hold, _type) then
		parse_addition(object, split[6], true)
	end

	table.insert(self.objects, object)
end

---@return string[]
function HitObjects:encode()
	local out = {}

	for _, object in ipairs(self.objects) do
		local extra = ""

		if is_type(HitObjectType.Slider, object.type) then
			if object.length == 0 then
				goto continue
			end
			extra = extra .. object.curveType .. "|"
			for _, p in ipairs(object.points) do
				extra = extra .. p[1] .. ":" .. p[2] .. "|"
			end
			extra = extra:gsub("|$", "")
			extra = extra .. "," .. object.repeatCount
			extra = extra .. "," .. object.length
			if object.sounds then
				extra = extra .. ","
				for _, sound in ipairs(object.sounds) do
					extra = extra .. sound .. "|"
				end
				extra = extra:gsub("|$", "")
				extra = extra .. ","
				for i = 1, #object.ss do
					extra = extra .. object.ss[i] .. ":" .. object.ssa[i] .. "|"
				end
				extra = extra:gsub("|$", "")
				extra = extra .. (",%s:%s:%s:%s:%s"):format(
					object.sampleSet,
					object.addSampleSet,
					object.customSample,
					object.volume,
					object.sampleFile
				)
			end
		elseif is_type(HitObjectType.Spinner, object.type) then
			extra = ("%s,%s:%s:%s:%s:%s"):format(
				object.endTime,
				object.sampleSet,
				object.addSampleSet,
				object.customSample,
				object.volume,
				object.sampleFile
			)
		elseif is_type(HitObjectType.Normal, object.type) then
			extra = ("%s:%s:%s:%s:%s"):format(
				object.sampleSet,
				object.addSampleSet,
				object.customSample,
				object.volume,
				object.sampleFile
			)
		elseif is_type(HitObjectType.Hold, object.type) then
			extra = ("%s:%s:%s:%s:%s:%s"):format(
				object.endTime,
				object.sampleSet,
				object.addSampleSet,
				object.customSample,
				object.volume,
				object.sampleFile
			)
		end

		table.insert(out, ("%s,%s,%s,%s,%s,%s"):format(
			object.x,
			object.y,
			object.time,
			object.type,
			object.soundType,
			extra
		))
	    ::continue::
	end

	return out
end

return HitObjects
