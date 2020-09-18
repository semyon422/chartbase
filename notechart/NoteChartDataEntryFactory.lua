local NoteChartFactory = require("notechart.NoteChartFactory")

local NoteChartDataEntryFactory = {}

NoteChartDataEntryFactory.getEntries = function(self, fileDatas)
	local entries = {}
	local allNoteCharts = {}
	
	for _, fileData in ipairs(fileDatas) do
		print(fileData.path)
		local status, noteCharts = NoteChartFactory:getNoteCharts(fileData.path, fileData.content)
		
		if status then
			for _, noteChart in ipairs(noteCharts) do
				noteChart.metaData:set("hash", fileData.hash)

				local entry = self:getEntry(noteChart.metaData)
				
				entries[#entries + 1] = entry
				allNoteCharts[#allNoteCharts + 1] = noteChart
				entry.noteChartEntry = fileData.noteChartEntry
			end
		else
			print(noteCharts)
		end
	end

	return entries, allNoteCharts
end

NoteChartDataEntryFactory.getEntry = function(self, metaData)
	return metaData:getTable()
end

return NoteChartDataEntryFactory
