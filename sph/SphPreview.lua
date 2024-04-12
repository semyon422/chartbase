local class = require("class")
local byte = require("byte_new")
local bit = require("bit")
local Fraction = require("ncdk.Fraction")

---@class sph.SphPreview
---@operator call: sph.SphPreview
local SphPreview = class()

--[[
	header {
		uint8		version
		int16		start time of first interval
	}

	X... .... / 0 - time, 1 - note
	0X.. .... / 0 - abs, 1 - rel
	00X. .... / 0 - add seconds, 1 - set/add fraction
		0001 1111 / add 31 seconds
	001X .... / 0 - add fraction, 1 - set fraction
		0010 1111 / add 15/(16^2) = 0.00390625 - 4ms precision
		0011 1111 / set fraction to 15/16
	01.. .... / set fraction to ....../1000000 (0/64-63/64)

	1X.. .... / 0 - release, 1 - press, other bits for column (0-62) excluding 11 1111 (63)
	1011 1111 / add 63 to previous note column (allows inputs 0-125)

	1011 1111 / reserved
	1111 1111 / reserved
]]

local function decode_byte(n)
	return {
		type = bit.band(n, 0b10000000) == 0 and "time" or "note",
		t_abs_or_rel = bit.band(n, 0b01000000) == 0 and "abs" or "rel",
		t_abs_add_sec_or_frac = bit.band(n, 0b00100000) == 0 and "sec" or "frac",
		t_abs_add_sec = bit.band(n, 0b00011111),
		t_abs_frac_add_or_set = bit.band(n, 0b00010000) == 0 and "add" or "set",
		t_abs_add_frac = Fraction(bit.band(n, 0b00001111), 256),
		t_abs_set_frac = Fraction(bit.band(n, 0b00001111), 16),
		t_rel_set_frac = Fraction(bit.band(n, 0b00111111), 64),
		n_is_pressed = bit.band(n, 0b01000000) ~= 0,
		n_column = bit.band(n, 0b00111111),
		n_add_columns = bit.band(n, 0b00111111) == 0b00111111,
		reserved_0 = n == 0b10111111,
		reserved_1 = n == 0b11111111,
	}
end

function SphPreview:decode(s)
	local b = byte.buffer(#s)
	b:fill(s):seek(0)

	local version = b:uint8()
	local start_time = b:int16_le()

	local lines = {}
	local line
	local interval
	local function next_line()
		if interval then
			start_time = interval.int
		end
		interval = nil
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
				if obj.t_abs_add_sec_or_frac == "sec" then
					update_interval()
					interval.int = interval.int + obj.t_abs_add_sec
					interval.frac = Fraction(0)
				elseif obj.t_abs_add_sec_or_frac == "frac" then
					if obj.t_abs_frac_add_or_set == "add" then
						update_interval()
						interval.frac = interval.frac + obj.t_abs_add_frac
					elseif obj.t_abs_frac_add_or_set == "set" then
						update_interval()
						interval.frac = obj.t_abs_set_frac
					end
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

return SphPreview
