local EncodingConverter = require("notechart.EncodingConverter")

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
	level = 0,
	
	previewTime = 0,
	audioPath = "",
	stagePath = "",
	
	inputMode = ""
}

local bracketFindPattern = "%s.+%s$"
local bracketMatchPattern = "%s(.+)%s$"
local brackets = {
	{"%[", "%]"},
	{"%(", "%)"},
	{"%-", "%-"},
	{"\"", "\""},
	{"〔", "〕"},
	{"‾", "‾"},
	{"~", "~"}
}

local trimName = function(name)
	for i = 1, #brackets do
		local lb, rb = brackets[i][1], brackets[i][2]
		if name:find(bracketFindPattern:format(lb, rb)) then
			return name:match(bracketMatchPattern:format(lb, rb)), name:find(bracketFindPattern:format(lb, rb))
		end
	end
	return name, #name + 1
end

local splitTitle = function(title)
	local name, bracketStart = trimName(title)
	return title:sub(1, bracketStart - 1), name
end

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
			level			= 0,
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
		local title, name = splitTitle(EncodingConverter:fix(header["TITLE"]))
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "bms",
			title			= title,
			artist			= EncodingConverter:fix(header["ARTIST"]),
			source			= "BMS",
			tags			= "",
			name			= name,
			creator			= "",
			level			= header["PLAYLEVEL"],
			audioPath		= "",
			stagePath		= EncodingConverter:fix(header["STAGEFILE"]),
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
			title			= EncodingConverter:fix(ojn.str_title),
			artist			= EncodingConverter:fix(ojn.str_artist),
			source			= "o2jam",
			tags			= "",
			name			= O2jamDifficultyNames[index],
			creator			= EncodingConverter:fix(ojn.str_noter),
			level			= ojn.charts[index].level,
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
			level			= options["level"],
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
			level			= 0,
			audioPath		= qua["AudioFile"],
			stagePath		= qua["BackgroundFile"],
			previewTime		= (qua["SongPreviewTime"] or 0) / 1000,
			noteCount		= importer.noteCount,
			length			= importer.totalLength / 1000,
			bpm				= noteChart.importer.primaryBPM,
			inputMode		= noteChart.inputMode:getString(),
			minTime         = importer.minTime / 1000,
			maxTime         = importer.maxTime / 1000,
		})
	elseif noteChart.type == "sm" then
		local importer = noteChart.importer
		local sm = noteChart.importer.sm
		local header = sm.header
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "sm",
			title			= header["TITLE"],
			artist			= header["ARTIST"],
			source			= header["SUBTITLE"],
			tags			= "",
			name			= "Challenge",
			creator			= header["CREDIT"],
			level			= 0,
			audioPath		= header["MUSIC"],
			stagePath		= header["BACKGROUND"],
			previewTime		= header["SAMPLESTART"],
			noteCount		= importer.noteCount,
			length			= importer.totalLength,
			bpm				= 120,
			inputMode		= noteChart.inputMode:getString(),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime,
		})
	elseif noteChart.type == "midi" then
		local importer = noteChart.importer
		local mid = importer.mid
		self:setTable({
			hash			= "",
			index			= noteChart.index,
			format			= "mid",
			title			= EncodingConverter:fix(importer.title),
			artist			= "",
			source			= "",
			tags			= "",
			name			= "",
			creator			= "",
			level			= 0,
			audioPath		= "",
			stagePath		= "",
			previewTime		= 0,
			noteCount		= importer.noteCount,
			length			= mid.length,
			bpm				= mid.bpm,
			inputMode		= "88key",
			minTime         = mid.minTime,
			maxTime         = mid.maxTime
		})
	end
end

return MetaData
