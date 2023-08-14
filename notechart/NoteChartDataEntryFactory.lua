local NoteChartFactory = require("notechart.NoteChartFactory")

local NoteChartDataEntryFactory = {}

function NoteChartDataEntryFactory:getEntries(path, content, hash, noteChartEntry)
	print(path)
	local status, noteCharts = NoteChartFactory:getNoteCharts(path, content)

	local entries = {}
	if not status then
		print(noteCharts)
		return
	end

	for _, noteChart in ipairs(noteCharts) do
		local entry = noteChart.metaData
		entry.hash = hash
		entry.noteChartEntry = noteChartEntry
		entries[#entries + 1] = entry
	end

	return entries, noteCharts
end

return NoteChartDataEntryFactory
