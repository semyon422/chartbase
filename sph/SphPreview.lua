local class = require("class")
local byte = require("byte_new")
local table_util = require("table_util")
local bit = require("bit")
local Fraction = require("ncdk.Fraction")
local Line = require("sph.lines.Line")

---@class sph.SphPreview
---@operator call: sph.SphPreview
local SphPreview = class()

SphPreview.version = 0

--[[
	header {
		uint8		version: 0 - default, 1 - compact
		int16		start time of first interval
	}

	default type:

	X... .... / 0 - offset/time, 1 - note
	0X.. .... / 0 - offset, 1 - time
	00X. .... / 0 - add integer seconds, 1 - add fraction seconds
		000. .... / add integer seconds (1-32)
		000. .... / add integer seconds (1-32)*32
		000. .... / add integer seconds (1-32)*32*32
		001Q WE.. .... .... / add QWE int seconds (0-7), add .../1024 seconds
	01X. .... / 0 - denominator is 16, 1 - denominator is 12
	01.X .... / 0 - single byte, 1 - double byte
		0100 .... / ..../16
		0110 .... / ..../12
		0101 :::: .... .... / ......../(16*(::::+1))
		0111 :::: .... .... / ......../(12*(::::+1))

	1X.. .... / 0 - release, 1 - press, other bits for column (0-62) excluding 11 1111 (63)
	1011 1111 / add 63 to previous note column (allows inputs 0-125)

	1111 1111 / reserved

	----------------------------------------------------------------------------

	compact type:

	1X.. .... / 0 - release, 1 - press
	1.X. .... / 0/1 switching value adds 5 to column allowing 5k+ modes
		1100 0011 / press 1-2 keys
		1001 1000 / release 4-5 keys
		1110 0001 / press 6 key
		1100 0001 / press 11 key

	----------------------------------------------------------------------------

	the following 64 denominators can be precisely encoded
	marked ones are encoded using a single byte, others use 2 bytes

	v v v v   v   v          v           v
	1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 18 20 21 22 24 26 27 28 30 32
	33 36 39 40 42 44 45 48 52 54 56 60 64
	66 72 78 80 84 88 90 96
	104 108 112 120 128
	132 144 156 160
	168 176 180 192
	208 224 240 256

	other will be rounded down to 1/256
]]

---@class sph.PreviewLine
---@field time ncdk.Fraction?
---@field notes boolean[]?
---@field offset number?
local PreviewLine = {}

---@param n number
---@param version number
---@return table
local function decode_byte(n, version)
	local t_is_12th = bit.band(n, 0b00100000) ~= 0
	local time_den = t_is_12th and 12 or 16
	local t_is_double = bit.band(n, 0b00010000) ~= 0
	local bt = {
		type = bit.band(n, 0b10000000) == 0 and "time" or "note",
		t_abs_or_rel = bit.band(n, 0b01000000) == 0 and "abs" or "rel",
		t_abs_add_sec_or_frac = bit.band(n, 0b00100000) == 0 and "sec" or "frac",
		offset_i = bit.band(n, 0b00011111),
		offset_f_int = bit.rshift(bit.band(n, 0b00011100), 2),
		offset_f_left = bit.lshift(bit.band(n, 0b00000011), 8),
		offset_f_right = bit.band(n, 0b11111111),

		t_is_double = t_is_double,
		time_den = time_den,
		time_single = bit.band(n, 0b00001111),
		time_double = bit.band(n, 0b11111111),

		n_is_pressed = bit.band(n, 0b01000000) ~= 0,
	}
	if version == 0 then
		bt.n_column = bit.band(n, 0b00111111)
		bt.n_add_columns = bit.band(n, 0b00111111) == 0b00111111
		bt.reserved_1 = n == 0b11111111
	elseif version == 1 then
		bt.n_columns_group = bit.band(n, 0b00100000) ~= 0
		local columns = {}
		for i = 1, 5 do
			columns[i] = bit.band(n, bit.lshift(1, i - 1)) ~= 0
		end
		bt.n_columns = columns
	end

	return bt
end

---@param s string
---@return sph.PreviewLine[]
function SphPreview:decode(s)
	local b = byte.buffer(#s)
	b:fill(s):seek(0)

	local version = b:uint8()
	local start_time = b:int16_le()

	local g_offset, int_prec, columns_group
	local lines = {}
	local line
	local function next_line()
		if line and line.offset then
			start_time = math.floor(line.offset)
		end
		g_offset = 0
		int_prec = 0
		columns_group = false
		line = {}
		table.insert(lines, line)
	end

	local frac_part = false
	local double_den = nil

	while b.offset < b.size do
		local n = b:uint8()
		local obj = decode_byte(n, version)
		if frac_part then
			line.offset = line.offset + obj.offset_f_right / 1024
			frac_part = false
		elseif double_den then
			line.time = Fraction(obj.time_double, double_den)
			double_den = nil
		elseif obj.type == "time" then
			if obj.t_abs_or_rel == "abs" then
				line.offset = line.offset or start_time
				if obj.t_abs_add_sec_or_frac == "sec" then
					line.offset = line.offset + obj.offset_i * (32 ^ int_prec)
					int_prec = int_prec + 1
				elseif obj.t_abs_add_sec_or_frac == "frac" then
					line.offset = line.offset + obj.offset_f_int
					line.offset = line.offset + obj.offset_f_left / 1024
					frac_part = true
				end
			elseif obj.t_abs_or_rel == "rel" then
				next_line()
				if obj.t_is_double then
					double_den = (obj.time_single + 1) * obj.time_den
				elseif obj.time_single ~= 0 then
					line.time = Fraction(obj.time_single, obj.time_den)
				end
			end
		elseif obj.type == "note" then
			line.notes = line.notes or {}
			if version == 0 then
				line.notes[obj.n_column + 1] = obj.n_is_pressed
			elseif version == 1 then
				if obj.n_columns_group ~= columns_group then
					g_offset = g_offset + 5
					columns_group = obj.n_columns_group
				end
				for i = 1, 5 do
					if obj.n_columns[i] then
						line.notes[i + g_offset] = obj.n_is_pressed
					end
				end
			end
		end
	end

	return lines
end

---@param lines sph.PreviewLine[]
---@param version number?
---@return string
function SphPreview:encode(lines, version)
	version = version or self.version

	local b = byte.buffer(1e6)
	b:uint8(version)
	b:int16_le(0)

	local start_time, real_start_time

	for _, line in ipairs(lines) do
		if line.time then
			local den_16 = (line.time * 16)[2]
			local den_12 = (line.time * 12)[2]
			if 16 % line.time[2] == 0 then  -- 1,2,4,8,16
				b:uint8(0b01000000 + math.floor(16 * line.time[1] / line.time[2]))
			elseif 12 % line.time[2] == 0 then  -- 3,6,12
				b:uint8(0b01100000 + math.floor(12 * line.time[1] / line.time[2]))
			elseif den_16 <= 16 then  -- exact 1/(16*den_16)
				b:uint8(0b01010000 + (den_16 - 1))
				b:uint8(16 * den_16 * line.time[1] / line.time[2])
			elseif den_12 <= 16 then  -- exact 1/(12*den_12)
				b:uint8(0b01110000 + (den_12 - 1))
				b:uint8(12 * den_12 * line.time[1] / line.time[2])
			else  -- 1/256 approximation
				b:uint8(0b01011111)
				b:uint8(math.floor(256 * line.time[1] / line.time[2]))
			end
		else
			b:uint8(0b01000000)
		end
		if line.offset then
			if not real_start_time then
				real_start_time = math.floor(line.offset)
				start_time = real_start_time
			end
			local diff = line.offset - start_time
			if diff == 0 then
				b:uint8(0)
			elseif diff % 1 == 0 then
				while diff > 0 do
					local d = diff % 32
					diff = diff - d
					diff = diff / 32
					b:uint8(d)
				end
			else
				local int_diff = math.floor(line.offset) - start_time
				local frac_int_part = 0
				if int_diff <= 7 then
					frac_int_part = int_diff
				elseif int_diff <= 31 then
					b:uint8(int_diff)
				elseif int_diff <= 38 then
					b:uint8(31)
					frac_int_part = int_diff - 31
				else
					while int_diff > 0 do
						local d = int_diff % 32
						int_diff = int_diff - d
						int_diff = int_diff / 32
						b:uint8(d)
					end
				end
				local frac = line.offset % 1 * 1024
				local frac_left = bit.rshift(frac, 8)
				local frac_right = bit.band(frac, 0xFF)
				b:uint8(0b00100000 + bit.lshift(frac_int_part, 2) + frac_left)
				b:uint8(frac_right)
			end
			start_time = math.floor(line.offset)
		end
		local notes = line.notes
		if notes and version == 0 then
			for i = 1, 63 do
				local note = notes[i]
				if note ~= nil then
					local bt = 0b10000000
					if note then
						bt = bt + 0b01000000
					end
					bt = bt + i - 1
					b:uint8(bt)
				end
			end
		elseif notes and version == 1 then
			local max_c = table_util.max_index(notes)
			local columns_group = false
			local g_offset = 0
			while g_offset < max_c do
				local has_release, has_press = false, false
				for i = 1, 5 do
					if notes[i + g_offset] == false then
						has_release = true
					elseif notes[i + g_offset] == true then
						has_press = true
					end
				end
				if has_release then
					local bt = 0b10000000 + (columns_group and 0b00100000 or 0)
					for i = 1, 5 do
						if notes[i + g_offset] == false then
							bt = bt + bit.lshift(1, i - 1)
						end
					end
					b:uint8(bt)
				end
				if has_press then
					local bt = 0b11000000 + (columns_group and 0b00100000 or 0)
					for i = 1, 5 do
						if notes[i + g_offset] == true then
							bt = bt + bit.lshift(1, i - 1)
						end
					end
					b:uint8(bt)
				end
				g_offset = g_offset + 5
				columns_group = not columns_group
			end
		end
	end

	local offset = b.offset
	b:seek(1)
	b:int16_le(real_start_time)
	b:seek(0)

	return b:string(offset)
end

---@param pline sph.PreviewLine
---@param long_notes table
---@return sph.Line
local function preview_line_to_line(pline, long_notes)
	local line = Line()
	line.time = pline.time
	if pline.notes then
		local notes = {}
		for column, pr in pairs(pline.notes) do
			local note = {column = column}
			if pr == true then
				long_notes[column] = note
				note.type = "1"
			elseif pr == false then
				note.type = "3"
				long_notes[column].type = "2"
			end
			table.insert(notes, note)
		end
		line.notes = notes
	end
	if pline.offset then
		line.offset = pline.offset
	end
	return line
end

---@param plines sph.PreviewLine[]
---@return sph.Line[]
function SphPreview:previewLinesToLines(plines)
	local long_notes = {}
	local lines = {}
	for i, pline in ipairs(plines) do
		lines[i] = preview_line_to_line(pline, long_notes)
	end
	return lines
end

---@param s string
---@return sph.Line[]
function SphPreview:decodeLines(s)
	local lines = self:decode(s)
	return self:previewLinesToLines(lines)
end

---@param line sph.Line
---@param prev_pline sph.PreviewLine
---@param long_notes table
---@return table?
local function line_to_preview_line(line, prev_pline, long_notes)
	local notes
	if line.notes then
		if prev_pline and line.visual then
			prev_pline.notes = prev_pline.notes or {}
			notes = prev_pline.notes
		else
			notes = {}
		end
		for _, note in ipairs(line.notes) do
			local t
			if note.type == "1" then
				t = true
			elseif note.type == "2" then
				long_notes[note.column] = true
				t = true
			elseif note.type == "3" then
				assert(long_notes[note.column])
				long_notes[note.column] = nil
				t = false
			end
			notes[note.column] = t
		end
	end

	if line.visual then
		return
	end

	local pline = {}

	if line.offset then
		local time = line.offset
		local frac = time % 1
		local int = time - frac
		pline.offset = int + math.floor(frac * 1024) / 1024
	end

	pline.time = line.time

	if line.notes then
		pline.notes = notes
	end

	return pline
end

---@param lines sph.Line[]
---@return sph.PreviewLine[]
function SphPreview:linesToPreviewLines(lines)
	local long_notes = {}
	local plines = {}
	for _, line in ipairs(lines) do
		local prev_line = plines[#plines]
		local _line = line_to_preview_line(line, prev_line, long_notes)
		table.insert(plines, _line)
	end
	return plines
end

---@param _lines sph.Line[]
---@param version number?
---@return string
function SphPreview:encodeLines(_lines, version)
	local lines = self:linesToPreviewLines(_lines)
	return self:encode(lines, version)
end

return SphPreview
