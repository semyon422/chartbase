local EncodingConverter = require("notechart.EncodingConverter")

local bracketFind = "%s.+%s$"
local bracketMatch = "%s(.+)%s$"
local brackets = {
	{"%[", "%]"},
	{"%(", "%)"},
	{"%-", "%-"},
	{"\"", "\""},
	{"〔", "〕"},
	{"‾", "‾"},
	{"~", "~"}
}

local function trimName(name)
	for i = 1, #brackets do
		local lb, rb = brackets[i][1], brackets[i][2]
		if name:find(bracketFind:format(lb, rb)) then
			return name:match(bracketMatch:format(lb, rb)), name:find(bracketFind:format(lb, rb))
		end
	end
	return name, #name + 1
end

local function splitTitle(title)
	local name, bracketStart = trimName(title)
	return title:sub(1, bracketStart - 1), name
end

local O2jamDifficultyNames = {"Easy", "Normal", "Hard"}

return function(noteChart, importer)
	if noteChart.type == "osu" then
		local metadata = importer.osu.metadata
		return {
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
			bpm				= importer.primaryBPM,
			inputMode		= tostring(noteChart.inputMode),
			minTime         = importer.minTime / 1000,
			maxTime         = importer.maxTime / 1000,
		}
	elseif noteChart.type == "bms" then
		local bms = importer.bms
		local header = bms.header
		local title, name = splitTitle(EncodingConverter:fix(header["TITLE"]))
		return {
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
			inputMode		= tostring(noteChart.inputMode),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime
		}
	elseif noteChart.type == "o2jam" then
		local ojn = importer.ojn
		local index = noteChart.index
		return {
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
			inputMode		= tostring(noteChart.inputMode),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime
		}
	elseif noteChart.type == "ksm" then
		local ksh = importer.ksh
		local options = ksh.options
		return {
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
			inputMode		= tostring(noteChart.inputMode),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime
		}
	elseif noteChart.type == "quaver" then
		local qua = importer.qua
		return {
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
			bpm				= importer.primaryBPM,
			inputMode		= tostring(noteChart.inputMode),
			minTime         = importer.minTime / 1000,
			maxTime         = importer.maxTime / 1000,
		}
	elseif noteChart.type == "sm" then
		local sm = importer.sm
		local header = sm.header
		local index = noteChart.index
		local chart = sm.charts[index]
		return {
			hash			= "",
			index			= noteChart.index,
			format			= "sm",
			title			= EncodingConverter:fix(header["TITLE"]),
			artist			= EncodingConverter:fix(header["ARTIST"]),
			source			= EncodingConverter:fix(header["SUBTITLE"]),
			tags			= "",
			name			= chart.metaData[3],
			creator			= EncodingConverter:fix(header["CREDIT"]),
			level			= tonumber(chart.metaData[4]),
			audioPath		= EncodingConverter:fix(header["MUSIC"]),
			stagePath		= EncodingConverter:fix(header["BACKGROUND"]),
			previewTime		= EncodingConverter:fix(header["SAMPLESTART"]),
			noteCount		= importer.noteCount,
			length			= importer.totalLength,
			bpm				= sm.displayTempo or 0,
			inputMode		= tostring(noteChart.inputMode),
			minTime         = importer.minTime,
			maxTime         = importer.maxTime,
		}
	elseif noteChart.type == "midi" then
		local mid = importer.mid
		return {
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
			inputMode		= tostring(noteChart.inputMode),
			minTime         = mid.minTime,
			maxTime         = mid.maxTime
		}
	end
end
