local Section = require("osu.sections.Section")

---@class osu.KeyValue: osu.Section
---@operator call: osu.KeyValue
---@field entries {[string]: string}
local KeyValue = Section + {}

KeyValue.space = false

KeyValue.order = {
	"AudioFilename",
	"AudioLeadIn",
	"PreviewTime",
	"Countdown",
	"SampleSet",
	"StackLeniency",
	"Mode",
	"LetterboxInBreaks",
	"StoryFireInFront",
	"UseSkinSprites",
	"AlwaysShowPlayfield",
	"OverlayPosition",
	"SkinPreference",
	"EpilepsyWarning",
	"CountdownOffset",
	"SpecialStyle",
	"WidescreenStoryboard",
	"SamplesMatchPlaybackRate",
	"Bookmarks",
	"DistanceSpacing",
	"BeatDivisor",
	"GridSize",
	"TimelineZoom",
	"Title",
	"TitleUnicode",
	"Artist",
	"ArtistUnicode",
	"Creator",
	"Version",
	"Source",
	"Tags",
	"BeatmapID",
	"BeatmapSetID",
	"HPDrainRate",
	"CircleSize",
	"OverallDifficulty",
	"ApproachRate",
	"SliderMultiplier",
	"SliderTickRate",
}

---@param space boolean
function KeyValue:new(space)
	self.space = space
	self.entries = {}
end

---@param line string
function KeyValue:decodeLine(line)
	local key, value = line:match("^(%a+):%s?(.*)")
	if key then
		self.entries[key] = value
	end
end

---@return string[]
function KeyValue:encode()
	local out = {}

	local space = self.space and " " or ""

	local entries = self.entries
	for _, k in ipairs(self.order) do
		local entry = entries[k]
		if entry then
			table.insert(out, ("%s:%s%s"):format(k, space, entry))
		end
	end

	return out
end

return KeyValue
