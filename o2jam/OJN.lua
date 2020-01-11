local byte = require("aqua.byte")

local OJN = {}

local OJN_metatable = {}
OJN_metatable.__index = OJN

OJN.new = function(self, ojnString)
	local ojn = {}
	ojn.buffer = byte.buffer(ojnString, 0, #ojnString, true)
	ojn.charts = {{}, {}, {}}
	
	setmetatable(ojn, OJN_metatable)
	ojn:process()
	
	return ojn
end

OJN.genre_map = {"Ballad", "Rock", "Dance", "Techno", "Hip-hop", "Soul/R&B", "Jazz", "Funk", "Classical", "Traditional", "Etc"}

OJN.process = function(self)
	self:readHeader()
	self:readCover()
	for _, chart in ipairs(self.charts) do
		self:readChart(chart)
	end
end

OJN.readHeader = function(self)
	local buffer = self. buffer
	self.songid = byte.read_int32_le(buffer)
	self.signature = byte.read_int32_le(buffer)
	assert(self.signature, 0x006E6A6F)
	
	self.encode_version = byte.read_float_le(buffer)
	self.genre = byte.read_int32_le(buffer)
	self.str_genre = self.genre_map[(self.genre < 0 or self.genre > 10) and 10 or self.genre]
	self.bpm = byte.read_float_le(buffer)

	self.charts[1].level = byte.read_int16_le(buffer)
	self.charts[2].level = byte.read_int16_le(buffer)
	self.charts[3].level = byte.read_int16_le(buffer)
	byte.read_int16_le(buffer)
	
	self.charts[1].event_count = byte.read_int32_le(buffer)
	self.charts[2].event_count = byte.read_int32_le(buffer)
	self.charts[3].event_count = byte.read_int32_le(buffer)

	self.charts[1].notes = byte.read_int32_le(buffer)
	self.charts[2].notes = byte.read_int32_le(buffer)
	self.charts[3].notes = byte.read_int32_le(buffer)
	
	self.charts[1].measure_count = byte.read_int32_le(buffer)
	self.charts[2].measure_count = byte.read_int32_le(buffer)
	self.charts[3].measure_count = byte.read_int32_le(buffer)
	
	self.charts[1].package_count = byte.read_int32_le(buffer)
	self.charts[2].package_count = byte.read_int32_le(buffer)
	self.charts[3].package_count = byte.read_int32_le(buffer)
	
	self.old_encode_version = byte.read_int16_le(buffer)
	self.old_songid = byte.read_int16_le(buffer)
	self.old_genre = byte.read_string(buffer, 20)
	self.bmp_size = byte.read_int32_le(buffer)
	self.file_version = byte.read_int32_le(buffer)

	self.str_title = byte.read_string(buffer, 64)
	-- self.title = byte.bytes(self.str_title)

	self.str_artist = byte.read_string(buffer, 32)
	-- self.artist = byte.bytes(self.str_artist)

	self.str_noter = byte.read_string(buffer, 32)
	-- self.noter = byte.bytes(self.str_noter)

	self.sample_file = byte.read_string(buffer, 32)
	self.ojm_file = self.sample_file

	self.cover_size = byte.read_int32_le(buffer)

	self.charts[1].duration = byte.read_int32_le(buffer)
	self.charts[2].duration = byte.read_int32_le(buffer)
	self.charts[3].duration = byte.read_int32_le(buffer)

	self.charts[1].note_offset = byte.read_int32_le(buffer)
	self.charts[2].note_offset = byte.read_int32_le(buffer)
	self.charts[3].note_offset = byte.read_int32_le(buffer)
	self.cover_offset = byte.read_int32_le(buffer)

	self.charts[1].note_offset_end = self.charts[2].note_offset
	self.charts[2].note_offset_end = self.charts[3].note_offset
	self.charts[3].note_offset_end = self.cover_offset
end

OJN.readCover = function(self)
	local buffer = byte.buffer(self.buffer.string, self.cover_offset, self.cover_size, true)
	self.cover = byte.tostring(buffer)
end

OJN.readChart = function(self, chart)
	chart.buffer = byte.buffer(self.buffer.string, chart.note_offset, chart.note_offset_end - chart.note_offset, true)
	local buffer = chart.buffer
	chart.event_list = {}

	while buffer.length > 0 do
		local measure = byte.read_int32_le(buffer)
		local channel_number = byte.read_int16_le(buffer)
		local events_count = byte.read_int16_le(buffer)

		local channel
		if channel_number == 0 then
			channel = "TIME_SIGNATURE"
		elseif channel_number == 1 then
			channel = "BPM_CHANGE"
		elseif channel_number == 2 then
			channel = "NOTE_1"
		elseif channel_number == 3 then
			channel = "NOTE_2"
		elseif channel_number == 4 then
			channel = "NOTE_3"
		elseif channel_number == 5 then
			channel = "NOTE_4"
		elseif channel_number == 6 then
			channel = "NOTE_5"
		elseif channel_number == 7 then
			channel = "NOTE_6"
		elseif channel_number == 8 then
			channel = "NOTE_7"
		else
			channel = "AUTO_PLAY"
		end
		
		for i = 0, events_count - 1 do
			local position = i / events_count
			if channel == "BPM_CHANGE" or channel == "TIME_SIGNATURE" then
				local value = byte.read_float_le(buffer)
				if value ~= 0 then
					table.insert(chart.event_list, {
						channel = channel,
						measure = measure,
						position = position,
						value = value,
						type = "NONE"
					})
				end
			else
				local value = byte.read_int16_le(buffer)
				local volume_pan = byte.read_int8(buffer)
				local type = byte.read_uint8(buffer)
				if value ~= 0 then
					local volume = bit.band(bit.rshift(volume_pan, 4), 0x0F) / 16
					if volume == 0 then volume = 1 end
					
					local pan = bit.band(volume_pan, 0x0F)
					if pan == 0 then pan = 8 end
					pan = pan - 8
					pan = pan / 8
							
					value = value - 1
					
					local f = "NONE"

					if type % 8 > 3 then
						value = value + 1000
					end
					type = type % 4
					
					if type == 0 then
						f = "NONE"
					elseif type == 1 then
					elseif type == 2 then
						f = "HOLD"
					elseif type == 3 then
						f = "RELEASE"
					end
					
					table.insert(chart.event_list, {
						channel = channel,
						measure = measure,
						position = position,
						value = value,
						type = f,
						volume = volume,
						pan = pan
					})
				end
			end
		end
	end
end

return OJN
