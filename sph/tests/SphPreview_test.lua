local SphPreview = require("sph.SphPreview")
local Fraction = require("ncdk.Fraction")
local stbl = require("stbl")

local test = {}

local function bytes_to_string(t)
	local s = {}
	for i, v in ipairs(t) do
		s[i] = string.char(v)
	end
	return table.concat(s)
end

function test.one_note(t)
	local s = {
		0b0, 0b0, 0b0,  -- header
		0b01000000,  -- 0/1 new line
		0b11000000,  -- 1000
	}

	local lines = SphPreview:decode(bytes_to_string(s))
	t:tdeq(lines, {
		{time = {0, 1}, notes = {[1] = true}},
	})
end

function test.complex_case(t)
	local s = {
		0b0,
		0xFD, 0xFF,  -- -3s

		-- 1100 +1/2
		0b01100000,  -- +1/2
		0b11000000,  -- 1000
		0b11000001,  -- 0100

		-- - =-1.49609375 // -3 + 1 + 8/16 + 1/256
		0b01000000,  -- 0/1 new line
		0b00000001,  -- add 1s and set frac part to 0
		0b00111000,  -- set 8/16=0.5s
		0b00100001,  -- add 1/256=0.00390625s

		-- 1000
		0b01000000,  -- 0/1 new line
		0b11000000,  -- 1000

		-- 1000 +63/64
		0b01111111,  -- +63/64
		0b11000000,  -- 1000

		-- - =5 // -2 + 7
		0b01000000,  -- 0/1 new line
		0b00000111,  -- add 7s and set frac part to 0

		-- 10 +1/2
		0b01100000,  -- +1/2
		0b11000000,  -- 1000
	}

	local lines = SphPreview:decode(bytes_to_string(s))
	t:tdeq(lines, {
		{time = {1, 2}, notes = {true, true}},
		{time = {0, 1}, notes = {}, interval = {int = -2, frac = {129, 256}}},
		{time = {0, 1}, notes = {true}},
		{time = {63, 64}, notes = {true}},
		{time = {0, 1}, notes = {}, interval = {int = 5, frac = {0, 1}}},
		{time = {1, 2}, notes = {true}},
	})
end

return test
