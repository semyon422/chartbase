local Sm = require("stepmania.Sm")

local test = {}

function test.basic(t)
	local sm = Sm()

	sm:import([[
#TITLE:Title;
#BPMS:0=180
,16=240
,32=120;
#STOPS:;

//---------------dance-single - ----------------
#NOTES:
     dance-single:
     :
     Challenge:
     1:

     0.000,0.000,0.000,0.000,0.000:
  //  Measure 0
1000
0100
0010
0001
,  //  Measure 1
1000
0100
0010
0001
;
]])

	print(require("inspect")(sm))
end

return test
