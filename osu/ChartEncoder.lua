local IChartEncoder = require("notechart.IChartEncoder")
local Osu = require("osu.Osu")
local RawOsu = require("osu.RawOsu")
local HitObjects = require("osu.sections.HitObjects")
local Addition = require("osu.sections.Addition")
local mappings = require("osu.exportKeyMappings")

---@class osu.ChartEncoder: chartbase.IChartEncoder
---@operator call: osu.ChartEncoder
local ChartEncoder = IChartEncoder + {}

---@param chart_chartmetas {chart: ncdk2.Chart, chartmeta: sea.Chartmeta}[]
---@return string
function ChartEncoder:encode(chart_chartmetas)
	local osu = self:encodeOsu(chart_chartmetas[1].chart, chart_chartmetas[1].chartmeta)
	return osu:encode()
end

---@param chart ncdk2.Chart
---@param chartmeta sea.Chartmeta
---@return osu.Osu
function ChartEncoder:encodeOsu(chart, chartmeta)
	self.chart = chart
	self.chartmeta = chartmeta
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
	local chartmeta = self.chartmeta
	local rosu = self.rawOsu

	rosu.General.AudioFilename = chartmeta.audio_path
	rosu.General.PreviewTime = math.floor((chartmeta.preview_time or -1) * 1000)
	rosu.General.Mode = 3

	rosu.Metadata.Title = chartmeta.title
	rosu.Metadata.Artist = chartmeta.artist
	rosu.Metadata.Source = chartmeta.source
	rosu.Metadata.Tags = chartmeta.tags
	rosu.Metadata.Version = chartmeta.name
	rosu.Metadata.Creator = chartmeta.creator

	rosu.Difficulty.CircleSize = chart.inputMode:getColumns()

	rosu.Events.background = chartmeta.background_path
end

function ChartEncoder:encodeEventSamples()
	local columns = self.chart.inputMode:getColumns()
	local samples = self.rawOsu.Events.samples
	for _, note in self.chart.notes:iter() do
		if note.column:find("auto") == 1 and note.data.sounds[1] then
			table.insert(samples, {
				time = note:getTime(),
				name = note.data.sounds[1][1],
				volume = note.data.sounds[1][2],
			})
		end
	end
end

local allowedTypes = {
	tap = true,
	hold = true,
}

---@param obj osu.HitObject
---@param note ncdk2.LinkedNote
function ChartEncoder:encodeHitObjectSounds(obj, note)
	--- TODO: better impl for hitsounds and keysounds

	local startNote = note.startNote
	---@cast startNote notechart.Note

	local sounds = startNote.data.sounds
	if sounds and sounds[1] then
		obj.addition.sampleFile = sounds[1][1]
		obj.addition.volume = sounds[1][2] * 100
	end
end

function ChartEncoder:encodeHitObjects()
	local columns = self.chart.inputMode:getColumns()
	local inputMap = self.inputMap
	local objs = self.rawOsu.HitObjects
	for _, note in ipairs(self.chart.notes:getLinkedNotes()) do
		local key = inputMap[note:getColumn()]
		if key and allowedTypes[note:getType()] then
			---@type osu.HitObject
			local obj = {
				time = math.floor(note:getStartTime() * 1000),
				x = math.floor(512 / columns * (key - 0.5)),
				y = 192,
				type = 1,
				soundType = HitObjects.HitObjectType.Normal,
				addition = Addition(),
			}
			if note:isLong() then
				obj.type = HitObjects.HitObjectType.ManiaLong
				obj.endTime = math.floor(note:getEndTime() * 1000)
			end
			self:encodeHitObjectSounds(obj, note)
			table.insert(objs, obj)
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
	if layer.visuals.main then
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
end

return ChartEncoder
