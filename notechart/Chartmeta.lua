local tablecheck = require("typecheck.tablecheck")

return tablecheck([[(
	index: number?,
	format: string?,

	title: string?,
	artist: string?,
	name: string?,
	creator: string?,

	source: string?,
	tags: string?,

	audio_path: string?,
	preview_time: number?,

	background_path: string?,
	stage_path: string?,
	banner_path: string?,

	level: number?,
	tempo: number?,
	tempo_avg: number?,
	tempo_min: number?,
	tempo_max: number?,

	notes_count: number?,
	duration: number?,
	start_time: number?,

	inputmode: string,

	osu_beatmap_id: number?,
	osu_beatmapset_id: number?,
	osu_ranked_status: number?,

	has_video: boolean?,
	has_storyboard: boolean?,
	has_subtitles: boolean?,
	has_negative_speed: boolean?,
	has_stacked_notes: boolean?,

	breaks_count: number?,
)]])
