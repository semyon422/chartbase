local enums = {}

enums.ChannelEnum = {
	["01"] = {name = "BGM", inputType = "auto", inputIndex = 0},
	["02"] = {name = "Signature"},
	["03"] = {name = "Tempo"},
	["08"] = {name = "ExtendedTempo"},
	["09"] = {name = "Stop"},
	
	["04"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x04},
	["06"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x06},
	["07"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x07},
	["0A"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0A},
	["0B"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0B},
	["0C"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0C},
	["0D"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0D},
	["0E"] = {name = "BGA", inputType = "bmsbga", inputIndex = 0x0E},
	
	["11"] = {name = "Note", inputType = "key", inputIndex = 1},
	["12"] = {name = "Note", inputType = "key", inputIndex = 2},
	["13"] = {name = "Note", inputType = "key", inputIndex = 3},
	["14"] = {name = "Note", inputType = "key", inputIndex = 4},
	["15"] = {name = "Note", inputType = "key", inputIndex = 5},
	["18"] = {name = "Note", inputType = "key", inputIndex = 6},
	["19"] = {name = "Note", inputType = "key", inputIndex = 7},
	
	["16"] = {name = "Note", inputType = "scratch", inputIndex = 1},
	
	["51"] = {name = "Note", inputType = "key", inputIndex = 1, long = true},
	["52"] = {name = "Note", inputType = "key", inputIndex = 2, long = true},
	["53"] = {name = "Note", inputType = "key", inputIndex = 3, long = true},
	["54"] = {name = "Note", inputType = "key", inputIndex = 4, long = true},
	["55"] = {name = "Note", inputType = "key", inputIndex = 5, long = true},
	["58"] = {name = "Note", inputType = "key", inputIndex = 6, long = true},
	["59"] = {name = "Note", inputType = "key", inputIndex = 7, long = true},
	
	["56"] = {name = "Note", inputType = "scratch", inputIndex = 1, long = true},
	
	["21"] = {name = "Note", inputType = "key", inputIndex = 8},
	["22"] = {name = "Note", inputType = "key", inputIndex = 9},
	["23"] = {name = "Note", inputType = "key", inputIndex = 10},
	["24"] = {name = "Note", inputType = "key", inputIndex = 11},
	["25"] = {name = "Note", inputType = "key", inputIndex = 12},
	["28"] = {name = "Note", inputType = "key", inputIndex = 13},
	["29"] = {name = "Note", inputType = "key", inputIndex = 14},
	
	["26"] = {name = "Note", inputType = "scratch", inputIndex = 2},
	
	["61"] = {name = "Note", inputType = "key", inputIndex = 8, long = true},
	["62"] = {name = "Note", inputType = "key", inputIndex = 9, long = true},
	["63"] = {name = "Note", inputType = "key", inputIndex = 10, long = true},
	["64"] = {name = "Note", inputType = "key", inputIndex = 11, long = true},
	["65"] = {name = "Note", inputType = "key", inputIndex = 12, long = true},
	["68"] = {name = "Note", inputType = "key", inputIndex = 13, long = true},
	["69"] = {name = "Note", inputType = "key", inputIndex = 14, long = true},
	
	["66"] = {name = "Note", inputType = "scratch", inputIndex = 2, long = true},
	
	["D1"] = {name = "Note", inputType = "key", inputIndex = 1, mine = true},
	["D2"] = {name = "Note", inputType = "key", inputIndex = 2, mine = true},
	["D3"] = {name = "Note", inputType = "key", inputIndex = 3, mine = true},
	["D4"] = {name = "Note", inputType = "key", inputIndex = 4, mine = true},
	["D5"] = {name = "Note", inputType = "key", inputIndex = 5, mine = true},
	["D8"] = {name = "Note", inputType = "key", inputIndex = 6, mine = true},
	["D9"] = {name = "Note", inputType = "key", inputIndex = 7, mine = true},
	
	["D6"] = {name = "Note", inputType = "scratch", inputIndex = 1, mine = true},
	
	["E1"] = {name = "Note", inputType = "key", inputIndex = 8, mine = true},
	["E2"] = {name = "Note", inputType = "key", inputIndex = 9, mine = true},
	["E3"] = {name = "Note", inputType = "key", inputIndex = 10, mine = true},
	["E4"] = {name = "Note", inputType = "key", inputIndex = 11, mine = true},
	["E5"] = {name = "Note", inputType = "key", inputIndex = 12, mine = true},
	["E8"] = {name = "Note", inputType = "key", inputIndex = 13, mine = true},
	["E9"] = {name = "Note", inputType = "key", inputIndex = 14, mine = true},
	
	["E6"] = {name = "Note", inputType = "scratch", inputIndex = 2, mine = true},
}

enums.ChannelEnum5Keys = {
	["21"] = {name = "Note", inputType = "key", inputIndex = 6},
	["22"] = {name = "Note", inputType = "key", inputIndex = 7},
	["23"] = {name = "Note", inputType = "key", inputIndex = 8},
	["24"] = {name = "Note", inputType = "key", inputIndex = 9},
	["25"] = {name = "Note", inputType = "key", inputIndex = 10},
	
	["61"] = {name = "Note", inputType = "key", inputIndex = 6, long = true},
	["62"] = {name = "Note", inputType = "key", inputIndex = 7, long = true},
	["63"] = {name = "Note", inputType = "key", inputIndex = 8, long = true},
	["64"] = {name = "Note", inputType = "key", inputIndex = 9, long = true},
	["65"] = {name = "Note", inputType = "key", inputIndex = 10, long = true},
}

enums.BackChannelEnum = {
	["BGM"] = "01",
	["Signature"] = "02",
	["Tempo"] = "03",
	["ExtendedTempo"] = "08",
	["Stop"] = "09",
}

return enums
