local NoteChartFactory = require("notechart.NoteChartFactory")

local NoteChartDataEntryFactory = {}

---@param path string
---@param content string
---@param hash string
---@param noteChartEntry table
---@return table?
---@return table?
function NoteChartDataEntryFactory:getEntries(path, content, hash, noteChartEntry)
	print(path)
	local noteCharts, err = NoteChartFactory:getNoteCharts(path, content)

	local entries = {}
	if not noteCharts then
		print(err)
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
