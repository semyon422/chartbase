local class = require("class")

---@class osu.Barlines
---@operator call: osu.Barlines
local Barlines = class()

---@param tempo_points osu.FilteredPoint[]
---@param lastTime number
---@return number[]
function Barlines:generate(tempo_points, lastTime)
	local start = tempo_points[1].offset
	if start >= 0 then
		local measure_length = tempo_points[1].beatLength * tempo_points[1].signature
		start = start - math.ceil(start / measure_length) * measure_length
	end

	---@type number[]
	local barlines = {}
	for i = 1, #tempo_points do
		local p = tempo_points[i]
		local beatTime = p.offset
		if i == 1 then
			beatTime = start
		end

		local timeEnd = lastTime + 1
		if i < #tempo_points then
			timeEnd = tempo_points[i + 1].offset - 1
		end

		local measure_length = p.beatLength * p.signature
		if p.omitFirstBarLine then
			beatTime = beatTime + measure_length
		end

		while beatTime < timeEnd do
			table.insert(barlines, beatTime)
			beatTime = beatTime + measure_length
		end
	end
	return barlines
end

return Barlines
