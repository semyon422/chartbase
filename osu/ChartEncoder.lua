local IChartEncoder = require("notechart.IChartEncoder")
local Osu = require("osu.Osu")
local RawOsu = require("osu.RawOsu")
local HitObjects = require("osu.sections.HitObjects")
local Addition = require("osu.sections.Addition")
local mappings = require("osu.exportKeyMappings")

---@class osu.ChartEncoder: chartbase.IChartEncoder
---@operator call: osu.ChartEncoder
local ChartEncoder = IChartEncoder + {}

---@param charts ncdk2.Chart[]
---@return string
function ChartEncoder:encode(charts)
	local osu = self:encodeOsu(charts[1])
	return osu:encode()
end

---@param chart ncdk2.Chart
---@return osu.Osu
function ChartEncoder:encodeOsu(chart)
	self.chart = chart
	self.columns = chart.inputMode:getColumns()
	self.inputMap = chart.inputMode:getInputMap()

	local rawOsu = RawOsu()
	local osu = Osu(rawOsu)
	self.rawOsu = rawOsu
	self.osu = osu

	self:encodeMetadata()
	self:encodeEventSamples()
	self:encodeHitObjects()
	self:encodeTimingPoints()

	return osu
end

function ChartEncoder:encodeMetadata()
	local chart = self.chart
	local rosu = self.rawOsu

	rosu.General.AudioFilename = chart.chartmeta.audio_path
	rosu.General.PreviewTime = math.floor((chart.chartmeta.preview_time or -1) * 1000)
	rosu.General.Mode = 3

	rosu.Metadata.Title = chart.chartmeta.title
	rosu.Metadata.Artist = chart.chartmeta.artist
	rosu.Metadata.Source = chart.chartmeta.source
	rosu.Metadata.Tags = chart.chartmeta.tags
	rosu.Metadata.Version = chart.chartmeta.name
	rosu.Metadata.Creator = chart.chartmeta.creator

	rosu.Difficulty.CircleSize = chart.inputMode:getColumns()

	rosu.Events.background = chart.chartmeta.background_path
end

function ChartEncoder:encodeEventSamples()
	local columns = self.chart.inputMode:getColumns()
	local samples = self.rawOsu.Events.samples
	for _, note in self.chart.notes:iter() do
		if note.column == "auto" then
			table.insert(samples, {
				time = note:getTime(),
				name = note.sounds[1][1],
				volume = note.sounds[1][2],
			})
		end
	end
end

function ChartEncoder:encodeHitObjects()
	local columns = self.chart.inputMode:getColumns()
	local inputMap = self.inputMap
	local objs = self.rawOsu.HitObjects
	for _, note in self.chart.notes:iter() do
		local key = inputMap[note.column]
		if key then
			---@type osu.HitObject
			local obj = {
				time = math.floor(note:getTime() * 1000),
				x = math.floor(512 / columns * (key - 0.5)),
				y = 192,
				type = 1,
				soundType = HitObjects.HitObjectType.Normal,
				addition = Addition(),
			}
			if note.endNote then
				obj.type = HitObjects.HitObjectType.ManiaLong
				obj.endTime = note.endNote:getTime()
			end
			table.insert(objs, obj)
			--- TODO: hotsounds and keysounds
		end
	end
	objs:sort()
end

function ChartEncoder:encodeTimingPoints()
	local layer = self.chart.layers.main
	local tpoints = self.rawOsu.TimingPoints
	for _, p in pairs(layer.points) do
		---@type ncdk2.Tempo
		local tempo = p._tempo
		---@type ncdk2.Stop
		local stop = p._stop
		---@type ncdk2.Interval
		local interval = p._interval

		if tempo then
			table.insert(tpoints, {
				offset = p.absoluteTime * 1000,
				beatLength = tempo:getBeatDuration() * 1000,
				timeSignature = 4,  -- do later
				timingChange = true,
			})
		end
		if stop then
			table.insert(tpoints, {
				offset = p.absoluteTime * 1000,
				beatLength = 60000000,
				timingChange = true,
			})
			table.insert(tpoints, {
				offset = p.absoluteTime * 1000,
				beatLength = p.tempo:getBeatDuration() * 1000,
				timingChange = true,
			})
		end
		if interval then
			table.insert(tpoints, {
				offset = p.absoluteTime * 1000,
				beatLength = interval:getBeatDuration() * 1000,
				timeSignature = 4,  -- do later
				timingChange = true,
			})
		end
	end
	for _, p in ipairs(layer.visuals.main.points) do
		---@type ncdk2.Velocity
		local velocity = p._velocity
		if velocity then
			table.insert(tpoints, {
				offset = p.point.absoluteTime * 1000,
				beatLength = -100 / velocity.currentSpeed,
				timingChange = false,
			})
		end
	end
end

return ChartEncoder
