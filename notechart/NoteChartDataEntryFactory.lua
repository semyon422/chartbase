local NoteChartFactory = require("notechart.NoteChartFactory")

local NoteChartDataEntryFactory = {}

NoteChartDataEntryFactory.getEntries = function(self, fileDatas)
	local entries = {}
	
	for _, fileData in ipairs(fileDatas) do
		local status, noteCharts = NoteChartFactory:getNoteCharts(fileData.path, fileData.content)
		
		if status then
			for _, noteChart in ipairs(noteCharts) do
				noteChart.metaData:set("hash", fileData.hash)

				local entry = self:getEntry(noteChart.metaData)
				
				entries[#entries + 1] = entry
				entry.noteChartEntry = fileData.noteChartEntry
			end
		else
			print(noteCharts)
		end
	end

	return entries
end

NoteChartDataEntryFactory.getEntry = function(self, metaData)
	return metaData:getTable()
end

return NoteChartDataEntryFactory
