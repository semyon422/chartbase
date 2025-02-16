local class = require("class")

---@class chartbase.Chartmeta
---@operator call: chartbase.Chartmeta
---@field index number?
---@field format string?
---@field title string?
---@field artist string?
---@field name string?
---@field creator string?
---@field source string?
---@field tags string?
---@field audio_path string?
---@field preview_time number?
---@field audio_offset number?
---@field background_path string?
---@field stage_path string?
---@field banner_path string?
---@field level number?
---@field tempo number?
---@field tempo_avg number?
---@field tempo_min number?
---@field tempo_max number?
---@field notes_count number?
---@field duration number?
---@field start_time number?
---@field inputmode string
---@field osu_beatmap_id number?
---@field osu_beatmapset_id number?
---@field osu_ranked_status number?
---@field has_video boolean?
---@field has_storyboard boolean?
---@field has_subtitles boolean?
---@field has_negative_speed boolean?
---@field has_stacked_notes boolean?
---@field breaks_count number?
local Chartmeta = class()

return Chartmeta
