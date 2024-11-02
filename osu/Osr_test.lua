local Osr = require("osu.Osr")

local test = {}

---@param t testing.T
function test.basic(t)
	local path = "userdata/export/replay-mania_3469849_566302508.osr"
	local data = love.filesystem.read(path)

	local osr = Osr()
	osr:decode(love.filesystem.read(path))
	osr:decodeManiaEvents()
	local _data = osr:encode()
end

return test
