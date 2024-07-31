local class = require("class")
local MsdFile = require("stepmania.MsdFile")
local SongTagInfo = require("stepmania.SongTagInfo")
local StepsTagInfo = require("stepmania.StepsTagInfo")
local parser_helper = require("stepmania.parser_helper")
local Steps = require("stepmania.Steps")
local Song = require("stepmania.Song")

---@class stepmania.SSCLoader
---@operator call: stepmania.SSCLoader
local SSCLoader = class()

function SSCLoader:new()

end

---@param msd stepmania.MsdFile
---@param path string
---@param out stepmania.Song
---@param from_cache any
function SSCLoader:LoadFromSimfile(msd, path, out, from_cache)
	local state = "GETTING_SONG_INFO"
	local values = msd:getNumValues()
	---@type stepmania.Steps
	local new_notes
	local stepsTiming = TimingData.new(out.m_SongTiming.m_fBeat0OffsetInSeconds)

	local reused_song_info = SongTagInfo(self, out, path, from_cache)
	local reused_steps_info = StepsTagInfo(self, out, path, from_cache)

	for i = 1, values do
		local params = msd:getValue(i)
		local value_name = params[1]:upper()

		if state == "GETTING_SONG_INFO" then
			reused_song_info.params = params
			local handler = parser_helper.song_tag_handlers[value_name]
			if handler then
				handler(reused_song_info)
			elseif value_name:sub(1, #("BGCHANGES")) == "BGCHANGES" then
				-- SetBGChanges(reused_song_info)
			elseif value_name == "NOTEDATA" then
				state = "GETTING_STEP_INFO"
				new_notes = Steps(out)
				stepsTiming = TimingData.new(out.m_SongTiming.m_fBeat0OffsetInSeconds)
				reused_steps_info.has_own_timing = false
				reused_steps_info.steps = new_notes
				reused_steps_info.timing = stepsTiming
			end
		elseif state == "GETTING_STEP_INFO" then
			reused_steps_info.params = params
			local handler = parser_helper.steps_tag_handlers[value_name]
			if handler then
				handler(reused_steps_info)
			elseif value_name == "NOTES" or value_name == "NOTES2" then
				state = "GETTING_SONG_INFO"
				if reused_steps_info.has_own_timing then
					new_notes.m_Timing = stepsTiming
				end
				reused_steps_info.has_own_timing = false
				new_notes:SetSMNoteData(params[2])
				new_notes:TidyUpData()
				new_notes:SetFilename(path)
				out:addSteps(new_notes)
			elseif value_name == "STEPFILENAME" then
				state = "GETTING_SONG_INFO"
				if reused_steps_info.has_own_timing then
					new_notes.m_Timing = stepsTiming
				end
				reused_steps_info.has_own_timing = false
				new_notes:SetFilename(params[2])
				out:addSteps(new_notes)
			end
		end
	end

	return true
end

return SSCLoader
