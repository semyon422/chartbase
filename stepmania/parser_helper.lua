local parser_helper = {}

---@type {[string]: fun(info: stepmania.StepsTagInfo)}
parser_helper.steps_tag_handlers = {}

---@type {[string]: fun(info: stepmania.SongTagInfo)}
parser_helper.song_tag_handlers = {}

---@type {[string]: integer}
parser_helper.load_note_data_handlers = {}

return parser_helper
