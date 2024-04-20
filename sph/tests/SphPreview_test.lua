local SphPreview = require("sph.SphPreview")
local SphLines = require("sph.SphLines")
local TextLines = require("sph.lines.TextLines")
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

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	t:tdeq(lines, {
		{time = {0, 1}, notes = {true}},
	})
end

function test.visual_side(t)
	local s = {
		0b0, 0b0, 0b0,  -- header

		0b01000000,  -- 0/1 new line
		0b11000000,  -- 1000

		0b01000000,  -- 0/1 new line
		0b11000001,  -- 0100

		-- - =1
		0b01000000,  -- 0/1 new line
		0b00000000,  -- add 1s

		-- - =2
		0b01000000,  -- 0/1 new line
		0b00000000,  -- add 1s
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	t:tdeq(lines, {
		{time = {0, 1}, notes = {true}},
		{time = {0, 1}, notes = {nil, true}},
		{time = {0, 1}, notes = {}, interval = {int = 1, frac = {0, 1}}},
		{time = {0, 1}, notes = {}, interval = {int = 2, frac = {0, 1}}},
	})

	local sphLines = SphLines()
	sphLines:decode(SphPreview:decodeLines(str))

	sphLines.protoLines[2].visualSide = 1
	local lines1 = SphPreview:linesToPreviewLines(sphLines:encode())
	t:tdeq(lines1, {
		{time = {0, 1}, notes = {true, true}},
		{time = {0, 1}, notes = {}, interval = {int = 1, frac = {0, 1}}},
		{time = {0, 1}, notes = {}, interval = {int = 2, frac = {0, 1}}},
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

	local sphLines = SphLines()
	sphLines:decode(SphPreview:decodeLines(str))

	local tl = TextLines()
	tl.lines = sphLines:encode()
	tl.columns = 4
	t:eq(tl:encode(), [[
1100 +1/2
- =-1.49609375
1000
1000 +23/24
- =5
1000 +1/2]])

	local _str = SphPreview:encodeLines(sphLines:encode())
	-- print(stbl.encode(enc_lines))
	t:eq(_str, str)

	-- print()
	-- for i = 1, #str do
	-- 	print(i, tobits(str:byte(i, i)))
	-- end
	-- for i = 1, #_str do
	-- 	print(i, tobits(_str:byte(i, i)))
	-- end
end


function test.complex_case_2(t)
	local s = {
		0b1,
		0xFE, 0xFF,  -- -2s

		-- 1111111111
		0b01000000,  -- 0/1 new line
		0b11011111,  -- 1111100000
		0b11111111,  -- 0000011111

		-- 3000
		0b01000000,  -- 0/1 new line
		0b10000001,  -- 3000

		-- 1300
		0b01000000,  -- 0/1 new line
		0b10000010,  -- 0300
		0b11000001,  -- 1000

		-- - =-2
		0b01000000,  -- 0/1 new line
		0b00100000,  -- add 0/1

		-- - =5 // -2 + 7
		0b01000000,  -- 0/1 new line
		0b00000110,  -- add 7s and set frac part to 0
	}

	local str = bytes_to_string(s)
	local lines = SphPreview:decode(str)
	-- print(stbl.encode(lines))
	t:tdeq(lines, {
		{time = {0, 1}, notes = {true, true, true, true, true, true, true, true, true, true}},
		{time = {0, 1}, notes = {false}},
		{time = {0, 1}, notes = {true, false}},
		{time = {0, 1}, notes = {}, interval = {int = -2, frac = {0, 1}}},
		{time = {0, 1}, notes = {}, interval = {int = 5, frac = {0, 1}}},
	})

	local _str = SphPreview:encode(lines, 1)
	t:eq(_str, str)

	local sphLines = SphLines()
	sphLines:decode(SphPreview:decodeLines(str))

	local tl = TextLines()
	tl.lines = sphLines:encode()
	tl.columns = 10
	t:eq(tl:encode(), [[
1111111111
3000000000
1300000000
- =-2
- =5]])

	local _str = SphPreview:encodeLines(sphLines:encode(), 1)
	t:eq(_str, str)
end

return test
