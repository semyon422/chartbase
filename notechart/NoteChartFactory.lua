local bms		= require("bms")
local ksm		= require("ksm")
local o2jam		= require("o2jam")
local osu		= require("osu")
local quaver	= require("quaver")
local sph		= require("sph")
local midi		= require("midi")
local stepmania	= require("stepmania")

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
	sm = true
}

local UnrelatedContainerExtensions = {
	ojn = true,
	mid = true
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
	sm = stepmania.NoteChartImporter
}

NoteChartFactory.isRelatedContainer = function(self, path)
	return RelatedContainerExtensions[path:lower():match("^.+%.(.-)$")]
end

NoteChartFactory.isUnrelatedContainer = function(self, path)
	return UnrelatedContainerExtensions[path:lower():match("^.+%.(.-)$")]
end

NoteChartFactory.getNoteChartImporter = function(self, path)
	return NoteChartImporters[path:lower():match("^.+%.(.-)$")]
end

NoteChartFactory.deleteBOM = function(self, content)
	if content:sub(1, 3) == string.char(0xEF, 0xBB, 0xBF) then
		return content:sub(4, -1)
	end
	return content
end

NoteChartFactory.getNoteCharts = function(self, path, content, index, settings)
	local NoteChartImporter = assert(self:getNoteChartImporter(path), "Importer is not found for " .. path)
	local importer = NoteChartImporter:new()

	importer.path = path
	importer.content = self:deleteBOM(content)
	importer.index = index
	importer.settings = settings

	local status, err = xpcall(function() return importer:import() end, debug.traceback)

	if not status then
		return false, err
	end

	return true, importer.noteCharts
end

return NoteChartFactory
