local MidiLua = require("midi.MidiLua")

local MID = {}

local MID_metatable = {}
MID_metatable.__index = MID

MID.new = function(self, midString)
	local mid = {}

	setmetatable(mid, MID_metatable)
	mid:process(midString, path)

	return mid
end

MID.process = function(self, midString)
    -- opus format:
    -- my_opus = {
    --     96, -- MIDI-ticks per beat
    --     {   -- first track
    --         {'patch_change', 0, 1, 8},   -- events
    --         {'set_tempo', 0, 750000},    -- microseconds per beat
    --         -- 'note_on/off',  dtime, channel, note, velocity
    --         {'note_on',   5, 1, 25, 96},
    --         {'note_off', 96, 1, 25, 0},
    --         {'note_on',   0, 1, 29, 96},
    --         {'note_off', 96, 1, 29, 0},
    --     },
    --     {   -- second track
    --         {'note_on',   5, 1, 25, 96},
    --         {'note_off', 96, 1, 25, 0},
    --     }
    -- }
    local opus = MidiLua.midi2opus(midString)
    
    -- score format:
    -- my_score = {
    --     96,
    --     {
    --         {'patch_change', 0, 1, 8},
    --         -- 'note', start_time, duration, channel, pitch, velocity
    --         {'note',   5, 96, 1, 25, 98},
    --         {'note', 101, 96, 1, 29, 98},
    --     },
    -- }

    -- to_millisecs just changes the opus to:
    -- {
    --     1000,
    --     {
    --         {'set_tempo', 1000000},
    --         -- ...
    --     },
    --     {
    --         {'set_tempo', 1000000},
    --         -- ...
    --     }
    -- }
    -- regardless of the set_tempo differences between the tracks
	self.score = MidiLua.opus2score(MidiLua.to_millisecs(opus))

    -- calculate the bpm changes for the measure line
	local bpm = {}
	for _, event in ipairs(opus[2]) do -- opus instead of score, because to_millisecs sets all set_tempo changes to 1000000
		if event[1] == "set_tempo" then
			bpm[#bpm+1] = {
				dt = event[2] / 1000,
				bpm = math.floor((60000000 / event[3]) + 0.5) -- minute / microseconds
			}
		end
	end

	if #bpm == 0 then
		bpm[1] = {
			dt = 0,
			bpm = 60
		}
	elseif bpm[1]["dt"] ~= 0 then -- make sure the first bpm starts at 0
		bpm[1]["dt"] = 0
	end
	self.bpm = bpm
end

return MID
