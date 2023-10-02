local template_key = require("sph.template_key")

local test = {}

function test.base(t)
	local values = {
		{0, "00"},
		{1, "01"},
		{template_key.base - 1, "0#"},
		{template_key.base, "10"},
		{template_key.base ^ 2 - 2, "#$"},
		{template_key.base ^ 2 - 1, "##"},
	}

	for _, d in ipairs(values) do
		t:eq(template_key.encode(d[1]), d[2])
		t:eq(template_key.decode(d[2]), d[1])
	end
end

return test
