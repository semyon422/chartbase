local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Note = require("notechart.Note")
local Tempo = require("ncdk2.to.Tempo")
local MeasureLayer = require("ncdk2.layers.MeasureLayer")
local VisualColumns = require("ncdk2.visual.VisualColumns")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Mid = require("midi.MID")
local Visual = require("ncdk2.visual.Visual")
local Chartmeta = require("sea.chart.Chartmeta")
local Timings = require("sea.chart.Timings")
local Healths = require("sea.chart.Healths")

---@class midi.ChartDecoder: chartbase.IChartDecoder
---@operator call: midi.ChartDecoder
local ChartDecoder = IChartDecoder + {}

---@param s string
---@param hash string?
---@return {chart: ncdk2.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash)
	self.hash = hash
	local mid = Mid(s)
	local chart, chartmeta = self:decodeMid(mid)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

---@param mid midi.MID
---@return ncdk2.Chart
---@return sea.Chartmeta
function ChartDecoder:decodeMid(mid)
	self.mid = mid

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	local visual = Visual()
	layer.visuals.main = visual
	self.visual = visual
	self.visualColumns = VisualColumns(visual)

	for _, tempo in ipairs(mid.tempos) do
		local point = layer:getPoint(Fraction(tempo[1], 1000, true))
		point._tempo = Tempo(tempo[2])
		visual:getPoint(point)
	end

	chart.inputMode = InputMode({key = 88})

	local addedNotes = {}
	for i = 1, #self.mid.notes do
		self:processData(i, addedNotes)
	end

	self:processMeasureLines()

	chart:compute()

	local chartmeta = self:getChartmeta()

	return chart, chartmeta
end

---@return sea.Chartmeta
function ChartDecoder:getChartmeta()
	local mid = self.mid

	local chartmeta = {
		hash = self.hash,
		index = 1,
		format = "midi",
		title = self.title,
		tempo = mid.bpm,
		inputmode = tostring(self.chart.inputMode),
	}
	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta

	assert(chartmeta:validate())

	return chartmeta
end

---@param trackIndex number
---@param addedNotes table
function ChartDecoder:processData(trackIndex, addedNotes)
	local notes = self.mid.notes
	local chart = self.chart
	local layer = self.layer
	local visualColumns = self.visualColumns

	local startNote
	for _, event in ipairs(notes[trackIndex]) do
		if event[1] then
			local eventId = event[2] .. ":" .. event[3]

			local hs = tostring(event[3])
			chart.resources:add("sound", hs)

			local point = layer:getPoint(Fraction(event[2], 1000, true))

			local column = "key" .. event[3]
			if addedNotes[eventId] then
				column = "auto"
			end
			local vp = visualColumns:getPoint(point, column)

			startNote = Note(vp, column)
			startNote.sounds = {{hs, event[4]}}
			startNote.type = addedNotes[eventId] and "sample" or "note"

			chart.notes:insert(startNote)

			-- TODO: long notes?

			addedNotes[eventId] = true
		end
	end
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	local minTime = self.mid.minTime
	local maxTime = self.mid.maxTime

	local time = minTime

	-- TODO
end

return ChartDecoder
