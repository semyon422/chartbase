local SphLines = require("sph.SphLines")
local Fraction = require("ncdk.Fraction")

local test = {}

function test.decenc_1(t)
	local sl = SphLines()

	local lines = {
		"0100 +1/2 // comment",
		"1000 =0.01",
		"0100 +1/2",
		"1000",
		"0100 +1/2 x1.1 #1/2",
		"0004 v e0.5",
		"1000 x1",
		"0100 +1/2",
		"0010",
		"-",
		"-",
		"- =1.01",
	}
	for _, line in ipairs(lines) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	t:eq(sl.lines[1].comment, "comment")

	t:eq(sl:encode(), table.concat(lines, "\n"))
end

function test.decenc_2(t)
	local sl = SphLines()

	local lines_in = {
		"-",
		"- +1/2",
		"-",
		"- =0.01",
		"-",
		"- +1/2",
		"-",
		"- =1.01",
		"-",
		"- +1/2",
		"-",
	}
	local lines_out = {
		"- =0.01",
		"-",
		"-",
		"- =1.01",
	}
	for _, line in ipairs(lines_in) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	t:eq(sl:encode(), table.concat(lines_out, "\n"))
end

function test.decenc_3(t)
	local sl = SphLines()

	local lines_in = {
		"-",
		"1000 +1/2",
		"-",
		"- =0.01",
		"-",
		"1000 +1/2",
		"-",
		"- =1.01",
		"-",
		"1000 +1/2",
		"-",
	}
	local lines_out = {
		"- =0.01",
		"-",
		"-",
		"- =1.01",
	}
	for _, line in ipairs(lines_in) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	for _, line in ipairs(sl.lines) do
		line.notes = nil
	end

	t:eq(sl:encode(), table.concat(lines_out, "\n"))
end

function test.decenc_4(t)
	local sl = SphLines()

	local lines_in = {
		"1000 +1/2",
		"1000",
		"1000 +1/2",
		"-",
		"- =0.01",
		"- =1.01",
	}
	local lines_out = {
		"1000 +1/2",
		"-",
		"1000 +1/2",
		"-",
		"- =0.01",
		"- =1.01",
	}
	for _, line in ipairs(lines_in) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	sl.lines[2].notes = {}

	t:eq(sl:encode(), table.concat(lines_out, "\n"))
end

function test.decenc_5(t)
	local sl = SphLines()

	local lines_in = {
		"- =0 :0011## .0050",
		"- =1",
	}
	local lines_out = {
		"- =0 :0011## .0050",
		"- =1",
	}
	for _, line in ipairs(lines_in) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	t:eq(sl.lines[1].sounds[1], 0)
	t:eq(sl.lines[1].sounds[2], 85 + 1)
	t:eq(sl.lines[1].sounds[3], 85 ^ 2 - 1)

	t:eq(sl:encode(), table.concat(lines_out, "\n"))
end

function test.decenc_6(t)
	local sl = SphLines()

	local lines_in = {
		"1000 =0",
		"-",
		"-",
		"-",
		"1000 v",
		"-",
		"- =1",
	}
	local lines_out = {
		"1000 =0",
		"-",
		"-",
		"1000",
		"-",
		"- =1",
	}
	for _, line in ipairs(lines_in) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	t:eq(#sl.lines, #lines_in)
	t:eq(sl.lines[5].time, Fraction(3))

	sl:calcIntervals()
	sl:calcGlobalTime()

	t:eq(sl.lines[5].globalTime, Fraction(3))

	t:eq(sl:encode(), table.concat(lines_out, "\n"))
end

function test.decenc_7(t)
	local sl = SphLines()

	local lines_in = {
		"1000 =0",
		"-",
		"-",
		"- +1/2",
		"1000 v",
		"-",
		"- =1",
	}
	local lines_out = {
		"1000 =0",
		"-",
		"-",
		"1000 +1/2",
		"-",
		"- =1",
	}
	for _, line in ipairs(lines_in) do
		sl:decodeLine(line)
	end
	sl:updateTime()

	t:eq(sl:encode(), table.concat(lines_out, "\n"))
end

return test
