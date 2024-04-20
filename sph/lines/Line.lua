local class = require("class")

---@class sph.Line
---@operator call: sph.Line
---@field comment string?
---@field notes {column: number, type: string}[]?
---@field offset number?
---@field time ncdk.Fraction?
---@field visual true?
---@field measure ncdk.Fraction?
---@field sounds integer[]?
---@field volume integer[]?
---@field velocity {[1]: number, [2]: number, [3]: number}?
---@field expand number?
local Line = class()

return Line
