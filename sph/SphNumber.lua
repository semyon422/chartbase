local class = require("class")
local Fraction = require("ncdk.Fraction")

---@class sph.SphNumber
---@operator call: sph.SphNumber
local SphNumber = class()

---@param s string
---@return ncdk.Fraction?
function SphNumber:decode(s)
	local sign = 1
	if s:sub(1, 1) == "-" then
		sign = -1
		s = s:sub(2)
	end

	local n, d = s:match("^(%d+)/(%d+)$")
	if not n or not d then
		return
	end

	return Fraction(sign * tonumber(n), tonumber(d))
end

return SphNumber
