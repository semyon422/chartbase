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

function test.encode(t)
	t:tdeq(Sounds:decode(0, dec_add("0:0:0:0:"), dec_tp("0,0,100")), {{
		name = "soft-hitnormal",
		volume = 80,
	}})
	t:tdeq(Sounds:decode(8, dec_add("0:0:0:0:"), dec_tp("1,0,100")), {{
		name = "normal-hitclap",
		volume = 85,
	}})
	t:tdeq(Sounds:decode(0, dec_add("0:0:0:0:"), dec_tp("1,2,100")), {{
		name = "normal-hitnormal2",
		fallback_name = "normal-hitnormal",
		volume = 80,
	}})
	t:tdeq(Sounds:decode(0, dec_add("0:0:0:70:sound.wav"), dec_tp("0,0,100")), {{
		name = "sound.wav",
		volume = 70,
		is_keysound = true,
	}})
	t:tdeq(Sounds:decode(9, dec_add("1:2:3:20:"), dec_tp("0,0,100")), {
		{
			name = "normal-hitnormal3",
			fallback_name = "normal-hitnormal",
			volume = 80 * 20 / 100,
		},
		{
			name = "soft-hitclap3",
			fallback_name = "soft-hitclap",
			volume = 85 * 20 / 100,
		},
	})
end

function test.decode_1(t)
	local soundType, addition = Sounds:encode({
		{
			name = "normal-hitnormal2",
			fallback_name = "normal-hitnormal",
			volume = 80,
		},
		{
			name = "normal-hitclap2",
			fallback_name = "normal-hitclap",
			volume = 85,
		},
	})
	t:eq(soundType, 9)
	t:tdeq(addition, {
		sampleSet = 1,
		addSampleSet = 0,
		customSample = 2,
		volume = 100,
		sampleFile = "",
	})
end

function test.decode_2(t)
	local soundType, addition = Sounds:encode({{
		name = "sound.wav",
		volume = 70,
		is_keysound = true,
	}})
	t:eq(soundType, 0)
	t:tdeq(addition, {
		sampleSet = 0,
		addSampleSet = 0,
		customSample = 0,
		volume = 70,
		sampleFile = "sound.wav",
	})
end

return test
