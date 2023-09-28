local class = require("class")
local Fraction = require("ncdk.Fraction")

local SphNumber = class()

---@param s string
---@return ncdk.Fraction?
---@return number
---@return number
function SphNumber:decode(s)
	local sign = 1
	local signLength = 0
	if s:sub(1, 1) == "-" then
		sign = -1
		signLength = 1
		s = s:sub(2)
	end

	local n, d = s:match("^(%d+)/(%d+)")
	if n and d then
		local length = 1 + #n + #d + signLength
		local _d = tonumber(d)
		if _d == 0 then
			return nil, math.huge, length
		end
		local f = Fraction(sign * tonumber(n), tonumber(d))
		return f, f:tonumber(), length
	end

	local i, d = s:match("^(%d+)%.(%d+)")
	if i and d then
		local length = 1 + #i + #d
		local _n = sign * tonumber(s:sub(1, length))
		return Fraction(_n, 1000, true), _n, length + signLength
	end

	local i = s:match("^(%d+)")
	if i then
		local _n = sign * tonumber(i)
		return Fraction(_n), _n, #i + signLength
	end

	return Fraction(0), 0, 0
end

return SphNumber
