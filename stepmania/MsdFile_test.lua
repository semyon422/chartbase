local MsdFile = require("stepmania.MsdFile")

local test = {}

function test.basic(t)
	local msd = MsdFile()
	msd:read(table.concat({
		"// comment",
		"#q:w:e:r;",
		"#a:s;    ",
		"#z:x		",
		"#v    #b",
		"#c\r\n\t ",
	}, "\r\n"))


	t:eq(msd:getNumValues(), 5)

	t:eq(msd:getNumParams(1), 4)
	t:eq(msd:getNumParams(1000), 0)

	t:eq(msd:getParam(1, 1), "q")
	t:eq(msd:getParam(1, 1000), "")
	t:eq(msd:getParam(1000, 1), "")
	t:eq(msd:getParam(1000, 1000), "")

	t:tdeq(msd.values, {
		{"q","w","e","r"},
		{"a","s"},
		{"z","x"},
		{"v    #b"},
		{"c\r\n\t "},
	})
end

function test.unescape(t)
	-- reading #q\"w\"e;
	local msd = MsdFile()

	msd:read('#q\\"w\\"e;')
	t:eq(msd:getParam(1, 1), 'q\\"w\\"e')

	msd:read('#q\\"w\\"e;', true)
	t:eq(msd:getParam(2, 1), 'q\"w\"e')
end

return test
