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

---@param n number
---@return string
local function tobits(n)
	local t = {}
	for i = 1, 8 do
		t[i] = 0
	end
	local i = 8
	while n > 0 do
		local rest = n % 2
		t[i] = rest
		n = (n - rest) / 2
		i = i - 1
	end
	return ("0b%s"):format(table.concat(t))
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
		0xFE, 0xFF,  -- -2s

		-- 1100 +1/2
		0b01010000,  -- +1/2
		0b11000000,  -- 1000
		0b11000001,  -- 0100

		-- - =-1.49609375 // -2 + 16/32 + 4/1024
		0b01000000,  -- 0/1 new line
		0b00110000,  -- add 16/32=0.5s
		0b00100100,  -- add 4/1024=0.00390625s

		-- 1000
		0b01000000,  -- 0/1 new line
		0b11000000,  -- 1000

		-- 1000 +23/24
		0b01110111,  -- 23/24
		0b11000000,  -- 1000

		-- - =5 // -2 + 7
		0b01000000,  -- 0/1 new line
		0b00000110,  -- add 7s and set frac part to 0

		-- 1000 +1/2
		0b01010000,  -- +1/2
		0b11000000,  -- 1000
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	-- print(stbl.encode(lines))
	t:tdeq(lines, {
		{time = {1, 2}, notes = {true, true}},
		{time = {0, 1}, notes = {}, interval = {int = -2, frac = {129, 256}}},
		{time = {0, 1}, notes = {true}},
		{time = {23, 24}, notes = {true}},
		{time = {0, 1}, notes = {}, interval = {int = 5, frac = {0, 1}}},
		{time = {1, 2}, notes = {true}},
	})

	local _str = SphPreview:encode(lines)
	t:eq(_str, str)

	local sphLines = SphPreview:decodeSphLines(str, 4)
	t:eq(sphLines:encode(), [[
1100 +1/2
- =-1.49609375
1000
1000 +23/24
- =5
1000 +1/2]])

	local _str, enc_lines = SphPreview:encodeSphLines(sphLines)
	print(stbl.encode(enc_lines))
	t:eq(_str, str)

	-- print()
	-- for i = 1, #str do
	-- 	print(i, tobits(str:byte(i, i)))
	-- end
	-- for i = 1, #_str do
	-- 	print(i, tobits(_str:byte(i, i)))
	-- end
end

return test
