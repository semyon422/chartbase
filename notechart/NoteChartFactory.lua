local bms		= require("bms")
local ksm		= require("ksm")
local o2jam		= require("o2jam")
local osu		= require("osu")
local quaver	= require("quaver")
local sph		= require("sph")
local midi		= require("midi")

local NoteChartFactory = {}

local RelatedContainerExtensions = {
	[".osu"] = true,
	[".bms"] = true,
	[".bme"] = true,
	[".bml"] = true,
	[".pms"] = true,
	[".qua"] = true,
	[".ksh"] = true,
	[".sph"] = true
}

local UnrelatedContainerExtensions = {
	[".ojn"] = true,
	[".mid"] = true
}

local NoteChartImporters = {
	[".osu"] = osu.NoteChartImporter,
	[".qua"] = quaver.NoteChartImporter,
	[".bms"] = bms.NoteChartImporter,
	[".bme"] = bms.NoteChartImporter,
	[".bml"] = bms.NoteChartImporter,
	[".pms"] = bms.NoteChartImporter,
	[".ksh"] = ksm.NoteChartImporter,
	[".ojn"] = o2jam.NoteChartImporter,
	[".sph"] = sph.NoteChartImporter,
	[".mid"] = midi.NoteChartImporter
}

local sub = string.sub
NoteChartFactory.isRelatedContainer = function(self, path)
	return RelatedContainerExtensions[sub(path, -4, -1):lower()]
end

NoteChartFactory.isUnrelatedContainer = function(self, path)
	return UnrelatedContainerExtensions[sub(path, -4, -1):lower()]
end

NoteChartFactory.getNoteChartImporter = function(self, path)
	return NoteChartImporters[sub(path, -4, -1):lower()]
end

NoteChartFactory.getNoteCharts = function(self, path, content, index, settings)
	local NoteChartImporter = self:getNoteChartImporter(path)
	local importer = NoteChartImporter:new()

	importer.path = path
	importer.content = content
	importer.index = index
	importer.settings = settings

	local status, err = xpcall(function() return importer:import() end, debug.traceback)

	if not status then
		return false, err
	end
	
	return true, importer.noteCharts
end

return NoteChartFactory
