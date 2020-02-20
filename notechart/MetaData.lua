local MetaData = require("ncdk.MetaData"):new()

MetaData.defaults = {
	hash = "",
	index = 0,
	format = "",

	noteCount = 0,
	length = 0,
	maxTime = 0,
	minTime = 0,
	bpm = 0,

	title = "",
	artist = "",
	source = "",
	tags = "",
	name = "",
	creator = "",
	
	previewTime = 0,
	audioPath = "",
	stagePath = "",
	
	inputMode = ""
}

local O2jamDifficultyNames = {"Easy", "Normal", "Hard"}
MetaData.fillData = function(self)
	local noteChart = self.noteChart

	if noteChart.type == "osu" then
		local importer = noteChart.importer
		local metadata = importer.osu.metadata
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "osu",
			title			= metadata["Title"],
			artist			= metadata["Artist"],
			source			= metadata["Source"],
			tags			= metadata["Tags"],
			name			= metadata["Version"],
			creator			= metadata["Creator"],
			audioPath		= metadata["AudioFilename"],
			stagePath		= importer.osu.background,
			previewTime		= metadata["PreviewTime"] / 1000,
			noteCount		= importer.noteCount,
			length			= importer.totalLength / 1000,
			bpm				= noteChart.importer.primaryBPM,
			inputMode		= noteChart.inputMode:getString(),
			minTime         = importer.minTime / 1000,
			maxTime         = importer.maxTime / 1000,
		})
	elseif noteChart.type == "bms" then
		local importer = noteChart.importer
		local bms = importer.bms
		local header = bms.header
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "bms",
			title			= header["TITLE"],
			artist			= header["ARTIST"],
			source			= "BMS",
			tags			= "",
			name			= nil,
			creator			= "",
			audioPath		= "",
			stagePath		= header["STAGEFILE"],
			previewTime		= 0,
			noteCount		= importer.noteCount,
			length			= importer.totalLength,
			bpm				= bms.baseTempo or 0,
			inputMode		= noteChart.inputMode:getString(),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime
		})
	elseif noteChart.type == "o2jam" then
		local importer = noteChart.importer
		local ojn = importer.ojn
		local index = noteChart.index
		self:setTable({
			hash			= "",
			index			= index,
			format			= "ojn",
			title			= ojn.str_title,
			artist			= ojn.str_artist,
			source			= "o2jam",
			tags			= "",
			name			= O2jamDifficultyNames[index],
			creator			= ojn.str_noter,
			audioPath		= "",
			stagePath		= "",
			previewTime		= 0,
			noteCount		= ojn.charts[index].notes,
			length			= ojn.charts[index].duration,
			bpm				= ojn.bpm,
			inputMode		= "7key",
			minTime         = importer.minTime,
			maxTime         = importer.maxTime
		})
	elseif noteChart.type == "ksm" then
		local importer = noteChart.importer
		local ksh = importer.ksh
		local options = ksh.options
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "ksh",
			title			= options["title"],
			artist			= options["artist"],
			source			= "KSM",
			tags			= "",
			name			= options["difficulty"],
			creator			= options["effect"],
			audioPath		= importer.audioFileName,
			stagePath		= options["jacket"],
			previewTime		= (options["plength"] or 0) / 1000,
			noteCount		= importer.noteCount,
			length			= importer.totalLength,
			bpm				= 0,
			inputMode		= noteChart.inputMode:getString(),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime
		})
	elseif noteChart.type == "quaver" then
		local importer = noteChart.importer
		local qua = noteChart.importer.qua
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "qua",
			title			= qua["Title"],
			artist			= qua["Artist"],
			source			= qua["Source"],
			tags			= qua["Tags"],
			name			= qua["DifficultyName"],
			creator			= qua["Creator"],
			audioPath		= qua["AudioFile"],
			stagePath		= qua["BackgroundFile"],
			previewTime		= (qua["SongPreviewTime"] or 0) / 1000,
			noteCount		= importer.noteCount,
			length			= importer.totalLength / 1000,
			bpm				= noteChart.importer.primaryBPM,
			inputMode		= noteChart.inputMode:getString()
		})
	end
end

return MetaData
