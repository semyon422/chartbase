local RawOsu = require("osu.RawOsu")

local test = {}

local test_chart = [[
osu file format v14

[General]
AudioFilename: audio.mp3

[Editor]
BeatDivisor: 4

[Metadata]
Title:Example

[Difficulty]
OverallDifficulty:10

[Events]
//Background and Video events
0,0,"bg.jpg",0,0
//Break Periods
//Storyboard Layer 0 (Background)
//Storyboard Layer 1 (Fail)
//Storyboard Layer 2 (Pass)
//Storyboard Layer 3 (Foreground)
//Storyboard Layer 4 (Overlay)
//Storyboard Sound Samples
5,1000,0,"sample1.wav",100

[TimingPoints]
0,222.222222222222,4,2,0,70,1,0
1000,-100,4,2,0,80,0,0


[HitObjects]
320,0,0,128,0,1000:1:0:0:0:
64,192,1000,5,6,0:0:0:0:]]

test_chart = test_chart:gsub("\n", "\r\n")

function test.basic(t)
	local raw_osu = RawOsu()

	raw_osu:decode(test_chart)
	t:eq(raw_osu:encode(), test_chart)
end

return test
