local KeyValue = require("osu.sections.KeyValue")

local test = {}

function test.basic(t)
	local key_value = KeyValue()

	local lines = {
		"a:b",
		"c:d",
	}

	key_value:decode(lines)
	t:eq(#key_value.entries, #lines)
	t:tdeq(key_value:encode(), lines)
end

function test.basic_space(t)
	local key_value = KeyValue(true)

	local lines = {
		"a: b",
		"c: d",
	}

	key_value:decode(lines)
	t:eq(#key_value.entries, #lines)
	t:tdeq(key_value:encode(), lines)
end

return test
