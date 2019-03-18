local byte = require("aqua.byte")

local OJN = {}

local OJN_metatable = {}
OJN_metatable.__index = OJN

OJN.new = function(self, ojnString)
	local ojn = {}
	ojn.buffer = byte.buffer(ojnString, true)
	ojn.charts = {{}, {}, {}}
	
	setmetatable(ojn, OJN_metatable)
	ojn:process()
	
	return ojn
end

OJN.genre_map = {"Ballad", "Rock", "Dance", "Techno", "Hip-hop", "Soul/R&B", "Jazz", "Funk", "Classical", "Traditional", "Etc"}

OJN.process = function(self)
	self:readHeader()
	for _, chart in ipairs(self.charts) do
		self:readChart(chart)
	end
end

OJN.readHeader = function(self)
	self.songid = byte.getInteger(self.buffer, 4)
	self.signature = byte.getInteger(self.buffer, 4)
	assert(self.signature, 0x006E6A6F)
	
	self.encode_version = byte.getFloat(self.buffer)
	self.genre = byte.getInteger(self.buffer, 4)
	self.str_genre = self.genre_map[(self.genre < 0 or self.genre > 10) and 10 or self.genre]
	self.bpm = byte.getFloat(self.buffer)

	self.charts[1].level = byte.getInteger(self.buffer, 2)
	self.charts[2].level = byte.getInteger(self.buffer, 2)
	self.charts[3].level = byte.getInteger(self.buffer, 2)
	byte.getInteger(self.buffer, 2)
	
	self.charts[1].event_count = byte.getInteger(self.buffer, 4)
	self.charts[2].event_count = byte.getInteger(self.buffer, 4)
	self.charts[3].event_count = byte.getInteger(self.buffer, 4)

	self.charts[1].notes = byte.getInteger(self.buffer, 4)
	self.charts[2].notes = byte.getInteger(self.buffer, 4)
	self.charts[3].notes = byte.getInteger(self.buffer, 4)
	
	self.charts[1].measure_count = byte.getInteger(self.buffer, 4)
	self.charts[2].measure_count = byte.getInteger(self.buffer, 4)
	self.charts[3].measure_count = byte.getInteger(self.buffer, 4)
	
	self.charts[1].package_count = byte.getInteger(self.buffer, 4)
	self.charts[2].package_count = byte.getInteger(self.buffer, 4)
	self.charts[3].package_count = byte.getInteger(self.buffer, 4)
	
	self.old_encode_version = byte.getInteger(self.buffer, 2)
	self.old_songid = byte.getInteger(self.buffer, 2)
	self.old_genre = {byte.bytes(byte.get(self.buffer, 20))}
	self.bmp_size = byte.getInteger(self.buffer, 4)
	self.file_version = byte.getInteger(self.buffer, 4)

	self.str_title = byte.tostring(byte.get(self.buffer, 64))
	self.title = byte.bytes(self.str_title)

	self.str_artist = byte.tostring(byte.get(self.buffer, 32))
	self.artist = byte.bytes(self.str_artist)

	self.str_noter = byte.tostring(byte.get(self.buffer, 32))
	self.noter = byte.bytes(self.str_noter)

	self.sample_file = byte.tostring(byte.get(self.buffer, 32))
	self.ojm_file = self.sample_file

	self.cover_size = byte.getInteger(self.buffer, 4)

	self.charts[1].duration = byte.getInteger(self.buffer, 4)
	self.charts[2].duration = byte.getInteger(self.buffer, 4)
	self.charts[3].duration = byte.getInteger(self.buffer, 4)

	self.charts[1].note_offset = byte.getInteger(self.buffer, 4)
	self.charts[2].note_offset = byte.getInteger(self.buffer, 4)
	self.charts[3].note_offset = byte.getInteger(self.buffer, 4)
	self.cover_offset = byte.getInteger(self.buffer, 4)

	self.charts[1].note_offset_end = self.charts[2].note_offset
	self.charts[2].note_offset_end = self.charts[3].note_offset
	self.charts[3].note_offset_end = self.cover_offset
end

OJN.readChart = function(self, chart)
	chart.buffer = byte.buffer(byte.read(self.buffer, chart.note_offset, chart.note_offset_end - chart.note_offset), true)
	chart.event_list = {}

	while chart.buffer.remaining > 0 do
		local measure = byte.getInteger(chart.buffer, 4)
		local channel_number = byte.getInteger(chart.buffer, 2)
		local events_count = byte.getInteger(chart.buffer, 2)

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
				local value = byte.getFloat(chart.buffer)
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
				local value = byte.getInteger(chart.buffer, 2)
				local volume_pan = byte.getInteger(chart.buffer, 1)
				local type = byte.getInteger(chart.buffer, 1)
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
