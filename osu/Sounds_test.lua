local Sounds = require("osu.Sounds")

local test = {}

---@param s string
---@return osu.Addition
local function dec_add(s)  -- s:a:c:v:f
	local split = s:split(":")
	return {
		sampleSet = tonumber(split[1]),
		addSampleSet = tonumber(split[2]),
		customSample = tonumber(split[3]),
		volume = tonumber(split[4]),
		sampleFile = split[5],
	}
end

---@param s string
---@return osu.ControlPoint
local function dec_tp(s)  -- 0,0,0,s,c,v,0,0
	local split = s:split(",")
	return {
		sampleSet = tonumber(split[1]),
		customSamples = tonumber(split[2]),
		volume = tonumber(split[3]),
	}
end

function test.basic(t)
	t:tdeq(Sounds:decode(0, dec_add("0:0:0:0:"), dec_tp("0,0,100")), {{
		name = "soft-hitnormal",
		volume = 80,
	}})
	t:tdeq(Sounds:decode(0, dec_add("0:0:0:0:"), dec_tp("1,2,100")), {{
		name = "normal-hitnormal2",
		fallback_name = "normal-hitnormal",
		volume = 80,
	}})
	t:tdeq(Sounds:decode(0, dec_add("0:0:0:70:sound.wav"), dec_tp("0,0,100")), {{
		name = "sound.wav",
		volume = 70,
	}})
end

return test
