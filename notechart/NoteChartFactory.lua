local bms = require("bms")
local ksm = require("ksm")
local o2jam = require("o2jam")
local osu = require("osu")
local quaver = require("quaver")
local sph = require("sph")
local midi = require("midi")
local stepmania = require("stepmania")

---@class notechart.NoteChartFactory
local NoteChartFactory = {}

local RelatedContainerExtensions = {
	osu = true,
	bms = true,
	bme = true,
	bml = true,
	pms = true,
	qua = true,
	ksh = true,
	sph = true,
	sm = true,
}

local UnrelatedContainerExtensions = {
	ojn = true,
	mid = true,
	midi = true,
}

local NoteChartImporters = {
	osu = osu.NoteChartImporter,
	qua = quaver.NoteChartImporter,
	bms = bms.NoteChartImporter,
	bme = bms.NoteChartImporter,
	bml = bms.NoteChartImporter,
	pms = bms.NoteChartImporter,
	ksh = ksm.NoteChartImporter,
	ojn = o2jam.NoteChartImporter,
	sph = sph.NoteChartImporter,
	mid = midi.NoteChartImporter,
	midi = midi.NoteChartImporter,
	sm = stepmania.NoteChartImporter
}

---@param path string
---@return boolean?
function NoteChartFactory:isRelatedContainer(path)
	return RelatedContainerExtensions[path:lower():match("^.+%.(.-)$")]
end

---@param path string
---@return boolean?
function NoteChartFactory:isUnrelatedContainer(path)
	return UnrelatedContainerExtensions[path:lower():match("^.+%.(.-)$")]
end

---@param path string
---@return table
function NoteChartFactory:getNoteChartImporter(path)
	local Importer = NoteChartImporters[path:lower():match("^.+%.(.-)$")]
	assert(Importer, "Importer is not found for " .. path)
	return Importer()
end

---@param content string
---@return string
function NoteChartFactory:deleteBOM(content)
	if content:sub(1, 3) == string.char(0xEF, 0xBB, 0xBF) then
		return content:sub(4, -1)
	end
	return content
end

---@param path string
---@param content string
---@return table?
---@return string?
function NoteChartFactory:getNoteCharts(path, content)
	local importer = self:getNoteChartImporter(path)

	importer.path = path
	importer.content = self:deleteBOM(content)

	local status, err = xpcall(function() return importer:import() end, debug.traceback)

	if not status then
		return nil, err
	end

	return importer.noteCharts
end

---@param path string
---@param content string
---@param index number
---@param settings table?
---@return ncdk.NoteChart?
---@return string?
function NoteChartFactory:getNoteChart(path, content, index, settings)
	local importer = self:getNoteChartImporter(path)

	importer.path = path
	importer.content = self:deleteBOM(content)
	importer.index = index
	importer.settings = settings

	local status, err = xpcall(function() return importer:import() end, debug.traceback)

	if not status then
		return nil, err
	end

	return importer.noteCharts[1]
end

return NoteChartFactory
