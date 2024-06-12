local class = require("class")
local path_util = require("path_util")

---@class notechart.ChartFactory
---@operator call: notechart.ChartFactory
local ChartFactory = class()

local ChartDecoders = {
	osu = require("osu.ChartDecoder"),
	sph = require("sph.ChartDecoder"),
	ojn = require("o2jam.ChartDecoder"),
	bms = require("bms.ChartDecoder"),
	sm = require("stepmania.ChartDecoder"),
	qua = require("quaver.ChartDecoder"),
	mid = require("midi.ChartDecoder"),
	midi = require("midi.ChartDecoder"),
	ksh = require("ksm.ChartDecoder"),
}

---@param filename string
---@return chartbase.IChartDecoder
function ChartFactory:getChartDecoder(filename)
	---@type chartbase.IChartDecoder
	local Decoder = assert(ChartDecoders[path_util.ext(filename, true)])
	return Decoder()
end

---@param filename string
---@param content string
---@return ncdk2.Chart[]?
---@return string?
function ChartFactory:getCharts(filename, content)
	---@type chartbase.IChartDecoder
	local decoder = assert(ChartDecoders[path_util.ext(filename, true)], filename)()
	local status, charts = xpcall(decoder.decode, debug.traceback, decoder, content)
	if not status then
		return nil, charts
	end
	return charts
end

return ChartFactory
