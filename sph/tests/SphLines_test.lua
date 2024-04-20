local SphLines = require("sph.SphLines")
local Fraction = require("ncdk.Fraction")

local test = {}

function test.decenc_1(t)
	local sl = SphLines()

	local lines_in = {
		{},
		{offset = 0},
		{},
		{fraction = Fraction(1, 2)},
		{},
		{fraction = Fraction(1, 2), notes = {true}},
		{},
		{offset = 1},
		{},
	}
	local lines_out = {
		{offset = 0},
		{},
		{},
		{fraction = Fraction(1, 2), notes = {true}},
		{},
		{offset = 1},
	}
	sl:decode(lines_in)
	local lines = sl:encode()
	t:tdeq(lines, lines_out)
end

return test
