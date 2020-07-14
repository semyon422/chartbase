local byte = require("byte")

local OJN = {}

local OJN_metatable = {}
OJN_metatable.__index = OJN

OJN.new = function(self, ojnString)
	local ojn = {}

	ojn.buffer = byte.buffer(#ojnString):fill(ojnString):seek(0)

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
	self.songid = buffer:int32_le()
	self.signature = buffer:int32_le()
	assert(self.signature, 0x006E6A6F)

	self.encode_version = buffer:float_le()
	self.genre = buffer:int32_le()
	self.str_genre = self.genre_map[(self.genre < 0 or self.genre > 10) and 10 or self.genre]
	self.bpm = buffer:float_le()

	self.charts[1].level = buffer:int16_le()
	self.charts[2].level = buffer:int16_le()
	self.charts[3].level = buffer:int16_le()
	buffer:int16_le()

	self.charts[1].event_count = buffer:int32_le()
	self.charts[2].event_count = buffer:int32_le()
	self.charts[3].event_count = buffer:int32_le()

	self.charts[1].notes = buffer:int32_le()
	self.charts[2].notes = buffer:int32_le()
	self.charts[3].notes = buffer:int32_le()

	self.charts[1].measure_count = buffer:int32_le()
	self.charts[2].measure_count = buffer:int32_le()
	self.charts[3].measure_count = buffer:int32_le()

	self.charts[1].package_count = buffer:int32_le()
	self.charts[2].package_count = buffer:int32_le()
	self.charts[3].package_count = buffer:int32_le()

	self.old_encode_version = buffer:int16_le()
	self.old_songid = buffer:int16_le()
	self.old_genre = buffer:cstring(20)
	self.bmp_size = buffer:int32_le()
	self.file_version = buffer:int32_le()

	self.str_title = buffer:cstring(64)
	-- self.title = byte.bytes(self.str_title)

	self.str_artist = buffer:cstring(32)
	-- self.artist = byte.bytes(self.str_artist)

	self.str_noter = buffer:cstring(32)
	-- self.noter = byte.bytes(self.str_noter)

	self.sample_file = buffer:cstring(32)
	self.ojm_file = self.sample_file

	self.cover_size = buffer:int32_le()

	self.charts[1].duration = buffer:int32_le()
	self.charts[2].duration = buffer:int32_le()
	self.charts[3].duration = buffer:int32_le()

	self.charts[1].note_offset = buffer:int32_le()
	self.charts[2].note_offset = buffer:int32_le()
	self.charts[3].note_offset = buffer:int32_le()
	self.cover_offset = buffer:int32_le()

	self.charts[1].note_offset_end = self.charts[2].note_offset
	self.charts[2].note_offset_end = self.charts[3].note_offset
	self.charts[3].note_offset_end = self.cover_offset
end

OJN.readCover = function(self)
	self.cover = self.buffer:seek(self.cover_offset):string(self.cover_size)
end

OJN.readChart = function(self, chart)
	local buffer = self.buffer:seek(chart.note_offset)
	chart.event_list = {}

	while buffer.offset < chart.note_offset_end do
		local measure = buffer:int32_le()
		local channel_number = buffer:int16_le()
		local events_count = buffer:int16_le()

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
				local value = buffer:float_le()
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
				local value = buffer:int16_le()
				local volume_pan = buffer:int8()
				local type = buffer:uint8()
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
