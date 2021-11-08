local NoteChartFactory = require("notechart.NoteChartFactory")

local NoteChartDataEntryFactory = {}

NoteChartDataEntryFactory.getEntries = function(self, path, content, hash, noteChartEntry)
	print(path)
	local status, noteCharts = NoteChartFactory:getNoteCharts(path, content)

	local entries = {}
	if not status then
		print(noteCharts)
		return
	end

	for _, noteChart in ipairs(noteCharts) do
		noteChart.metaData:set("hash", hash)

		local entry = noteChart.metaData:getTable()

		entries[#entries + 1] = entry
		entry.noteChartEntry = noteChartEntry
	end

	return entries, noteCharts
end

return NoteChartDataEntryFactory
