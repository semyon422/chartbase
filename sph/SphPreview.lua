local class = require("class")
local byte = require("byte_new")
local bit = require("bit")
local Fraction = require("ncdk.Fraction")
local SphLines = require("sph.SphLines")

---@class sph.SphPreview
---@operator call: sph.SphPreview
local SphPreview = class()

SphPreview.version = 0

--[[
	header {
		uint8		version
		int16		start time of first interval
	}

	X... .... / 0 - time, 1 - note
	0X.. .... / 0 - abs, 1 - rel
	00X. .... / 0 - add seconds, 1 - set fraction
		0001 1111 / add 32 seconds (1-32)
		0011 1111 / set fraction to 31/32
		0011 1111 / set fraction to 31/32 + 31/(32^2)
		0011 1111 / set fraction to 31/32 + 31/(32^2) + 31/(32^3)
	01X. .... / 0 - denominator is 2^5=32, 1 - denominator is 3*2^3=24

	011. .... / 24-31 unused

	1X.. .... / 0 - release, 1 - press, other bits for column (0-62) excluding 11 1111 (63)
	1011 1111 / add 63 to previous note column (allows inputs 0-125)

	1111 1111 / reserved
]]

local function decode_byte(n)
	local t_is_24th = bit.band(n, 0b00100000) ~= 0
	return {
		type = bit.band(n, 0b10000000) == 0 and "time" or "note",
		t_abs_or_rel = bit.band(n, 0b01000000) == 0 and "abs" or "rel",
		t_abs_add_sec_or_frac = bit.band(n, 0b00100000) == 0 and "sec" or "frac",
		t_abs_add_sec = bit.band(n, 0b00011111) + 1,
		t_abs_set_frac = Fraction(bit.band(n, 0b00011111), 32),
		t_is_24th = bit.band(n, 0b00100000) ~= 0,
		t_rel_set_frac = Fraction(bit.band(n, 0b00011111), t_is_24th and 24 or 32),
		n_is_pressed = bit.band(n, 0b01000000) ~= 0,
		n_column = bit.band(n, 0b00111111),
		n_add_columns = bit.band(n, 0b00111111) == 0b00111111,
		reserved_1 = n == 0b11111111,
	}
end

function SphPreview:decode(s)
	local b = byte.buffer(#s)
	b:fill(s):seek(0)

	local version = b:uint8()
	local start_time = b:int16_le()

	local frac_prec = 0
	local lines = {}
	local line
	local interval
	local function next_line()
		if interval then
			start_time = interval.int
		end
		interval = nil
		frac_prec = 0
		line = {
			time = Fraction(0),
			notes = {},
		}
		table.insert(lines, line)
	end

	local function update_interval()
		line.interval = line.interval or {
			int = start_time,
			frac = Fraction(0),
		}
		interval = line.interval
	end

	while b.offset < b.size do
		local n = b:uint8()
		local obj = decode_byte(n)
		if obj.type == "time" then
			if obj.t_abs_or_rel == "abs" then
				update_interval()
				if obj.t_abs_add_sec_or_frac == "sec" then
					interval.int = interval.int + obj.t_abs_add_sec
					interval.frac = Fraction(0)
				elseif obj.t_abs_add_sec_or_frac == "frac" then
					interval.frac = interval.frac + obj.t_abs_set_frac / (32 ^ frac_prec)
					frac_prec = frac_prec + 1
				end
			elseif obj.t_abs_or_rel == "rel" then
				next_line()
				line.time = obj.t_rel_set_frac
			end
		elseif obj.type == "note" then
			line.notes[obj.n_column + 1] = obj.n_is_pressed
		end
	end

	return lines
end

function SphPreview:encode(lines)
	local b = byte.buffer(1e6)
	b:uint8(self.version)
	b:int16_le(0)

	local start_time

	for _, line in ipairs(lines) do
		if line.time[2] % 3 == 0 then
			b:uint8(0b01100000 + math.floor(24 * line.time[1] / line.time[2]))
		else
			b:uint8(0b01000000 + math.floor(32 * line.time[1] / line.time[2]))
		end
		if line.interval then
			if not start_time then
				start_time = line.interval.int
			end
			local int_diff = line.interval.int - start_time
			while int_diff > 0 do
				local d = math.min(int_diff, 32)
				int_diff = int_diff - d
				b:uint8(d - 1)
			end
			local frac = line.interval.frac
			local frac1 = math.floor(32 * frac[1] / frac[2])
			local frac2 = math.floor(1024 * frac[1] / frac[2])
			if frac2 ~= 0 then
				b:uint8(0b00100000 + frac1)
				b:uint8(0b00100000 + frac2)
			elseif frac1 ~= 0 then
				b:uint8(0b00100000 + frac1)
			end
		end
		for i = 1, 63 do
			local note = line.notes[i]
			if note ~= nil then
				local bt = 0b10000000
				if note then
					bt = bt + 0b01000000
				end
				bt = bt + i - 1
				b:uint8(bt)
			end
		end
	end

	local offset = b.offset
	b:seek(1)
	b:int16_le(start_time)
	b:seek(0)

	return b:string(offset)
end

local function line_to_string(line, columns)
	local out = {}
	local notes = {}
	for i = 1, columns do
		local note = line.notes[i]
		if note == true then
			notes[i] = 1
		elseif note == false then
			notes[i] = 3
		else
			notes[i] = 0
		end
	end

	table.insert(out, table.concat(notes))

	if line.interval then
		local interval = line.interval.int + line.interval.frac
		table.insert(out, ("=%s"):format(interval))
	end
	if line.time[1] ~= 0 then
		table.insert(out, ("+%s/%s"):format(line.time[1], line.time[2]))
	end

	return table.concat(out, " ")
end

---@param s string
---@return sph.SphLines
function SphPreview:decodeSphLines(s, columns)
	local lines = self:decode(s)
	local sphLines = SphLines()
	for _, line in ipairs(lines) do
		sphLines:decodeLine(line_to_string(line, columns))
	end
	sphLines:updateTime()
	return sphLines
end

local function sph_line_to_preview_line(line, sphLines)
	local notes = {}
	for _, note in ipairs(line.notes) do
		local t
		if note.type == "1" or note.type == "2" then
			t = true
		elseif note.type == "3" then
			t = false
		end
		notes[note.column] = t
	end
	local interval
	if line.intervalSet then
		local time = sphLines.intervals[line.intervalIndex].offset
		local frac = time % 1
		local int = time - frac
		interval = {
			int = int,
			frac = Fraction(math.floor(frac * 1024), 1024),
		}
	end
	return {
		time = line.time % 1,
		notes = notes,
		interval = interval,
	}
end

---@param sphLines sph.SphLines
---@return string
---@return table
function SphPreview:encodeSphLines(sphLines)
	local lines = {}
	for i, line in ipairs(sphLines.lines) do
		lines[i] = sph_line_to_preview_line(line, sphLines)
	end
	return self:encode(lines), lines
end

return SphPreview
