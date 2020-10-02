local MidiLua = require("midi.MidiLua")

local MID = {}

local MID_metatable = {}
MID_metatable.__index = MID

MID.new = function(self, midString, path)
	local mid = {}

	setmetatable(mid, MID_metatable)
	mid:process(midString, path)

	return mid
end

MID.process = function(self, midString, path)
	local opus = MidiLua.midi2opus(midString)
	self.score = MidiLua.opus2score(MidiLua.to_millisecs(opus))

	self.title = path:match("^.*/(.*).mid$")

	local bpm = {}
	for _, event in ipairs(opus[2]) do
		if event[1] == "set_tempo" then
			bpm[#bpm+1] = {
				dt = event[2] / 1000,
				bpm = math.floor((60000000 / event[3]) + 0.5)
			}
		end
	end

	if #bpm == 0 then
		bpm[1] = {
			dt = 0,
			bpm = 60
		}
	elseif bpm[1]["dt"] ~= 0 then
		bpm[1]["dt"] = 0
	end
	self.bpm = bpm
end

return MID
