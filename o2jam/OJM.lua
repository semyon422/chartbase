local byte = require("byte")

local OJM = {}

local OJM_metatable = {}
OJM_metatable.__index = OJM

OJM.new = function(self, ojmString)
	local ojm = {}
	
	ojm.buffer = byte.buffer(ojmString, true)
	ojm.samples = {}
	ojm.acc_keybyte = 0xFF
	ojm.acc_counter = 0
	
	setmetatable(ojm, OJM_metatable)
	
	ojm:process()
	
	return ojm
end

OJM.mask_nami = {0x6E, 0x61, 0x6D, 0x69}
OJM.mask_0412 = {0x30, 0x34, 0x31, 0x32}

OJM.M30_SIGNATURE = 0x0030334D
OJM.OMC_SIGNATURE = 0x00434D4F
OJM.OJM_SIGNATURE = 0x004D4A4F

OJM.REARRANGE_TABLE = {
	0x10, 0x0E, 0x02, 0x09, 0x04, 0x00, 0x07, 0x01,
	0x06, 0x08, 0x0F, 0x0A, 0x05, 0x0C, 0x03, 0x0D,
	0x0B, 0x07, 0x02, 0x0A, 0x0B, 0x03, 0x05, 0x0D,
	0x08, 0x04, 0x00, 0x0C, 0x06, 0x0F, 0x0E, 0x10,
	0x01, 0x09, 0x0C, 0x0D, 0x03, 0x00, 0x06, 0x09,
	0x0A, 0x01, 0x07, 0x08, 0x10, 0x02, 0x0B, 0x0E,
	0x04, 0x0F, 0x05, 0x08, 0x03, 0x04, 0x0D, 0x06,
	0x05, 0x0B, 0x10, 0x02, 0x0C, 0x07, 0x09, 0x0A,
	0x0F, 0x0E, 0x00, 0x01, 0x0F, 0x02, 0x0C, 0x0D,
	0x00, 0x04, 0x01, 0x05, 0x07, 0x03, 0x09, 0x10,
	0x06, 0x0B, 0x0A, 0x08, 0x0E, 0x00, 0x04, 0x0B,
	0x10, 0x0F, 0x0D, 0x0C, 0x06, 0x05, 0x07, 0x01,
	0x02, 0x03, 0x08, 0x09, 0x0A, 0x0E, 0x03, 0x10,
	0x08, 0x07, 0x06, 0x09, 0x0E, 0x0D, 0x00, 0x0A,
	0x0B, 0x04, 0x05, 0x0C, 0x02, 0x01, 0x0F, 0x04,
	0x0E, 0x10, 0x0F, 0x05, 0x08, 0x07, 0x0B, 0x00,
	0x01, 0x06, 0x02, 0x0C, 0x09, 0x03, 0x0A, 0x0D,
	0x06, 0x0D, 0x0E, 0x07, 0x10, 0x0A, 0x0B, 0x00,
	0x01, 0x0C, 0x0F, 0x02, 0x03, 0x08, 0x09, 0x04,
	0x05, 0x0A, 0x0C, 0x00, 0x08, 0x09, 0x0D, 0x03,
	0x04, 0x05, 0x10, 0x0E, 0x0F, 0x01, 0x02, 0x0B,
	0x06, 0x07, 0x05, 0x06, 0x0C, 0x04, 0x0D, 0x0F,
	0x07, 0x0E, 0x08, 0x01, 0x09, 0x02, 0x10, 0x0A,
	0x0B, 0x00, 0x03, 0x0B, 0x0F, 0x04, 0x0E, 0x03,
	0x01, 0x00, 0x02, 0x0D, 0x0C, 0x06, 0x07, 0x05,
	0x10, 0x09, 0x08, 0x0A, 0x03, 0x02, 0x01, 0x00,
	0x04, 0x0C, 0x0D, 0x0B, 0x10, 0x05, 0x06, 0x0F,
	0x0E, 0x07, 0x09, 0x0A, 0x08, 0x09, 0x0A, 0x00,
	0x07, 0x08, 0x06, 0x10, 0x03, 0x04, 0x01, 0x02,
	0x05, 0x0B, 0x0E, 0x0F, 0x0D, 0x0C, 0x0A, 0x06,
	0x09, 0x0C, 0x0B, 0x10, 0x07, 0x08, 0x00, 0x0F,
	0x03, 0x01, 0x02, 0x05, 0x0D, 0x0E, 0x04, 0x0D,
	0x00, 0x01, 0x0E, 0x02, 0x03, 0x08, 0x0B, 0x07,
	0x0C, 0x09, 0x05, 0x0A, 0x0F, 0x04, 0x06, 0x10,
	0x01, 0x0E, 0x02, 0x03, 0x0D, 0x0B, 0x07, 0x00,
	0x08, 0x0C, 0x09, 0x06, 0x0F, 0x10, 0x05, 0x0A,
	0x04, 0x00
}

OJM.process = function(self)
	local buffer = byte.buffer(byte.read(self.buffer, 0, 4), true)
	self.signature = byte.getInteger(buffer, 4)
	
	if self.signature == self.M30_SIGNATURE then
		self:parseM30()
	elseif self.signature == self.OMC_SIGNATURE then 
		self:parseOMC(true)
	elseif self.signature == self.OJM_SIGNATURE then
		self:parseOMC(false)
	end
end

OJM.parseM30 = function(self)
	local buffer = byte.buffer(byte.read(self.buffer, 4, 28), true)
	
	local file_format_version = byte.getInteger(buffer, 4)
	local encryption_flag = byte.getInteger(buffer, 4)
	local sample_count = byte.getInteger(buffer, 4)
	local sample_offset = byte.getInteger(buffer, 4)
	local payload_size = byte.getInteger(buffer, 4)
	local padding = byte.getInteger(buffer, 4)
	
	buffer = byte.buffer(byte.read(self.buffer, 28, self.buffer.size - 28), true)
	
	for i = 0, sample_count - 1 do
		if buffer.remaining < 52 then
			break
		end
		
		local sample_name = byte.get(buffer, 32)
		local byte_name = {byte.bytes(sample_name)}
		
		if not sample_name:find(".") then sample_name = sample_name .. ".ogg" end
			
		local sample_size = byte.getInteger(buffer, 4)

		local codec_code = byte.getInteger(buffer, 2)
		local codec_code2 = byte.getInteger(buffer, 2)

		local music_flag = byte.getInteger(buffer, 4)
		local ref = byte.getInteger(buffer, 2)
		local unk_zero = byte.getInteger(buffer, 2)
		local pcm_samples = byte.getInteger(buffer, 4)

		local sample_data = {byte.bytes(byte.get(buffer, sample_size))}

		if encryption_flag == 0 then
		elseif encryption_flag == 16 then
			self:M30_xor(sample_data, self.mask_nami)
		elseif encryption_flag == 32 then
			self:M30_xor(sample_data, self.mask_0412)
		end

		local audioData = {
			sampleData = table.concat(sample_data)
		}
		local value = ref
		if codec_code == 0 then
			value = 1000 + ref
		elseif codec_code ~= 5 then
			
		end
		self.samples[value] = audioData
	end
end

OJM.M30_xor = function(self, array, mask)
	for i = 0, #array - 4, 4 do
		array[i + 1] = array[i + 1] ^ mask[1]
		array[i + 2] = array[i + 2] ^ mask[2]
		array[i + 3] = array[i + 3] ^ mask[3]
		array[i + 4] = array[i + 4] ^ mask[4]
	end
end

OJM.parseOMC = function(self, decrypt)
	local buffer = byte.buffer(byte.read(self.buffer, 4, 16), true)
	
	local unk1 = byte.getInteger(buffer, 2)
	local unk2 = byte.getInteger(buffer, 2)
	local wav_start = byte.getInteger(buffer, 4)
	local ogg_start = byte.getInteger(buffer, 4)
	local filesize = byte.getInteger(buffer, 4)

	local file_offset = 20
	local sample_id = 0

	local acc_keybyte = 0xFF
	local acc_counter = 0
	
	while file_offset < ogg_start do
		buffer = byte.buffer(byte.read(self.buffer, file_offset, 16), true)
		file_offset = file_offset + 56

		local sample_name = byte.get(buffer, 32)
		local byte_name = {byte.bytes(sample_name)}
		
		if not sample_name:find(".") then sample_name = sample_name .. ".wav" end

		local audio_format = byte.getInteger(buffer, 21)
		local num_channels = byte.getInteger(buffer, 2)
		local sample_rate = byte.getInteger(buffer, 4)
		local bit_rate = byte.getInteger(buffer, 4)
		local block_align = byte.getInteger(buffer, 2)
		local bits_per_sample = byte.getInteger(buffer, 2)
		local data = byte.getInteger(buffer, 4)
		local chunk_size = byte.getInteger(buffer, 4)

		if chunk_size == 0 then
			sample_id = sample_id + 1
		else
			local header = {} --WAVHeader(audio_format, num_channels, sample_rate, bit_rate, block_align, bits_per_sample, data, chunk_size);

			buffer = byte.buffer(byte.read(self.buffer, file_offset, chunk_size), true)
			file_offset = file_offset + chunk_size

			local buf = {byte.bytes(byte.get(buffer, buffer.remaining))}

			if decrypt then
				buf = self:rearrange(buf)
				buf = self:OMC_xor(buf)
			end

			-- buffer = ByteBuffer.allocateDirect(buf.length);
			-- buffer.put(buf);
			-- buffer.flip();

			local audioData = {
				sampleData = table.concat(buf)
			}
			self.samples[sample_id] = audioData
			sample_id = sample_id + 1
		end
	end
	
	sample_id = 1000
	while file_offset < filesize do
		buffer = byte.buffer(byte.read(self.buffer, file_offset, 36), true)
		file_offset = file_offset + 36

		local sample_name = byte.get(buffer, 32)
		local byte_name = {byte.bytes(sample_name)}
		
		if not sample_name:find(".") then sample_name = sample_name .. ".ogg" end
			
		local sample_size = byte.getInteger(buffer, 4)
		
		if sample_size == 0 then
			sample_id = sample_id + 1
		else
			buffer = byte.buffer(byte.read(self.buffer, file_offset, sample_size), true)
			file_offset = file_offset + sample_size

			local audioData = {
				sampleData = buffer.s
			}
			self.samples[sample_id] = audioData
			sample_id = sample_id + 1
		end
	end
end

OJM.rearrange = function(self, buf_encoded)
	local length = #buf_encoded
	local key = bit.lshift((length % 17), 4) + (length % 17)

	local block_size = length / 17

	local buf_plain = {}
	table.copy(buf_encoded, 0, buf_plain, 0, length)

	for block = 0, 16 do
		local block_start_encoded = block_size * block
		local block_start_plain = block_size * self.REARRANGE_TABLE[key]
		table.copy(buf_encoded, block_start_encoded, buf_plain, block_start_plain, block_size)

		key = key + 1
	end
	return buf_plain
end

OJM.OMC_xor = function(self, buf)
	local temp
	local this_byte
	for i = 1, #buf do
		temp = buf[i]
		this_byte = buf[i]

		if bit.band(bit.lshift(self.acc_keybyte, self.acc_counter), 0x80) ~= 0 then
			this_byte = bit.bnot(this_byte)
		end

		buf[i] = this_byte
		self.acc_counter = self.acc_counter + 1
		if self.acc_counter > 7 then
			self.acc_counter = 0
			self.acc_keybyte = temp
		end
	end
	return buf
end

return OJM
