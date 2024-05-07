local ChartLocation = require("notechart.ChartLocation")

local test = {}

function test.basic(t)
	local cl = ChartLocation()

	t:assert(cl:isRelated("file.osu"))
	t:assert(cl:isRelated("file.BMS"))
	t:assert(not cl:isRelated("file.ojn"))
	t:assert(not cl:isRelated("file.midi"))
end

return test
