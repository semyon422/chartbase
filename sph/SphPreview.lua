local class = require("class")

---@class sph.SphPreview
---@operator call: sph.SphPreview
local SphPreview = class()

--[[
	header {
		uint8		version
		uint8		inputs
		uint8[16]	hash
		int16		start time of first interval
	}

	X... .... / 0 - time, 1 - note
	0X.. .... / 0 - abs, 1 - rel
	00X. .... / 0 - add seconds, 1 - set fraction
		0001 1111 / add 31 seconds
		0011 1111 / set fraction part to .96875 (31/32), with rounding to nearest, should be +-16ms precision
	01.. .... / set fraction to ....../1000000 (0/64-63/64)

	1X.. .... / 0 - release, 1 - press, other bits for column (0-62) excluding 11 1111 (63)
	1011 1111 / add 63 to previous note column (allows inputs 0-125)

	1111 1111 / preview starts here
]]

return SphPreview
