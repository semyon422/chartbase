local class = require("class")
local SphNumber = require("sph.SphNumber")
local template_key = require("sph.template_key")

---@class sph.TextSphLines
---@operator call: sph.TextSphLines
local TextSphLines = class()

function TextSphLines:new()
	self.lines = {}
	self.columns = 1
end

---@param s string
---@param n number
---@return table
local function split_chars(s, n)
	local chars = {}
	for i = 1, #s, n do
		table.insert(chars, s:sub(i, i + n - 1))
	end
	return chars
end

---@param notes table
---@return table
local function parse_notes(notes)
	local out = {}
	for i, note in ipairs(notes) do
		if note ~= "0" then
			table.insert(out, {
				column = i,
				type = note,
			})
		end
	end
	return out
end

---@param sounds table
---@return table
local function parse_sounds(sounds)
	local out = {}
	for i, sound in ipairs(sounds) do
		out[i] = template_key.decode(sound)
	end
	return out
end

---@param volume table
---@return table
local function parse_volume(volume)
	local out = {}
	for i, vol in ipairs(volume) do
		vol = tonumber(vol) or 0
		if vol == 0 then
			vol = 100
		end
		out[i] = vol / 100
	end
	return out
end

---@param velocity string
---@return table
local function parse_velocity(velocity)
	local out = velocity:split(",")
	for i = 1, 3 do
		out[i] = tonumber(out[i]) or 1
	end
	return out
end

---@param s string
function TextSphLines:decodeLine(s)
	local line = {}

	local data, comment = s:match("^(.-) // (.+)$")
	if not data then
		data = s
	end
	line.comment = comment

	local args = data:split(" ")
	for i = 2, #args do
		local k, v = args[i]:match("^(.)(.*)$")

		if k == "=" then
			line.offset = tonumber(v)
		elseif k == "+" then
			line.fraction = SphNumber:decode(v)
		elseif k == "v" then
			line.visual = true
		elseif k == "#" then
			line.measure = SphNumber:decode(v)
		elseif k == ":" then
			line.sounds = parse_sounds(split_chars(v, 2))
		elseif k == "." then
			line.volume = parse_volume(split_chars(v, 2))
		elseif k == "x" then
			line.velocity = parse_velocity(v)
		elseif k == "e" then
			line.expand = tonumber(v)
		end
	end

	if args[1] ~= "-" then
		self.columns = math.max(self.columns, #args[1])
		local notes = split_chars(args[1], 1)
		line.notes = parse_notes(notes)
	end

	table.insert(self.lines, line)

	return line
end

---@param f ncdk.Fraction
---@return string
local function formatFraction(f)
	return f[1] .. "/" .. f[2]
end

---@param v table
---@return string
local function format_velocity(v)
	if v[3] ~= 1 then
		return ("%s,%s,%s"):format(v[1], v[2], v[3])
	end
	if v[2] ~= 1 then
		return ("%s,%s"):format(v[1], v[2])
	end
	return tostring(v[1])
end

---@param _notes table
---@return string?
function TextSphLines:getLine(_notes)
	if not _notes or #_notes == 0 then
		return
	end
	local notes = {}
	for i = 1, self.columns do
		notes[i] = "0"
	end
	for _, note in ipairs(_notes) do
		if note.column then
			notes[note.column] = note.type
		end
	end
	return table.concat(notes)
end

---@return string
function TextSphLines:encode()
	for _, line in ipairs(self.lines) do
		if line.notes then
			for _, note in ipairs(line.notes) do
				if note.column then
					self.columns = math.max(self.columns, note.column)
				end
			end
		end
	end

	local slines = {}

	for _, line in ipairs(self.lines) do
		local str = self:getLine(line.notes)

		str = str or "-"
		if line.offset then
			str = str .. " =" .. line.offset
		end
		if line.fraction and line.fraction[1] ~= 0 then
			str = str .. " +" .. formatFraction(line.fraction)
		end
		if line.visual then
			str = str .. " v"
		end
		if line.expand then
			str = str .. " e" .. tostring(line.expand)
		end
		if line.velocity then
			str = str .. " x" .. format_velocity(line.velocity)
		end
		if line.measure then
			local n = line.measure
			str = str .. " #" .. (n[1] ~= 0 and formatFraction(n) or "")
		end
		if line.sounds and #line.sounds > 0 then
			local out = {}
			for i, sound in ipairs(line.sounds) do
				out[i] = template_key.encode(sound)
			end
			str = str .. " :" .. table.concat(out)
		end
		if line.volume and #line.volume > 0 then
			local out = {}
			for i, vol in ipairs(line.volume) do
				out[i] = ("%02d"):format(math.floor(vol * 100 + 0.5) % 100)
			end
			str = str .. " ." .. table.concat(out)
		end
		if line.comment and #line.comment > 0 then
			str = str .. " // " .. line.comment
		end

		table.insert(slines, str)
	end

	return table.concat(slines, "\n")
end

return TextSphLines
