local KeyValue = require("osu.sections.KeyValue")

local test = {}

function test.basic(t)
	local key_value = KeyValue()

	local lines = {
		"Title:b",
		"Artist:d",
	}

	key_value:decode(lines)
	t:eq(key_value.entries.Title, "b")
	t:eq(key_value.entries.Artist, "d")
	t:tdeq(key_value:encode(), lines)
end

function test.basic_space(t)
	local key_value = KeyValue(true)

	local lines = {
		"Title: b",
		"Artist: d",
	}

	key_value:decode(lines)
	t:eq(key_value.entries.Title, "b")
	t:eq(key_value.entries.Artist, "d")
	t:tdeq(key_value:encode(), lines)
end

return test
