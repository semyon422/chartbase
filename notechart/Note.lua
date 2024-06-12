local Note = require("ncdk2.notes.Note")

---@alias notechart.NoteType
---| "ShortNote"
---| "LongNoteStart"
---| "LongNoteEnd"
---| "SoundNote"

---@class notechart.Note: ncdk2.Note
---@operator call: notechart.Note
---@field noteType notechart.NoteType
---@field sounds {[1]: string, [2]: number}[]
---@field images string[]
---@field startNote notechart.Note
---@field endNote notechart.Note
local _Note = Note + {}

_Note.__tostring = Note.__tostring
_Note.__eq = Note.__eq
_Note.__lt = Note.__lt
_Note.__le = Note.__le

return _Note
