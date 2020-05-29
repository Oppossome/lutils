local parsers = {}

local function registerParser(pattern, callback)
	pattern = (istable(pattern) and pattern or {pattern})
	table.insert(parsers, {pattern, callback})
end

function lutils.colorify(text, dontPrint)
	local parseData = {}
	parseData.commentBreaker = nil
	parseData.stringBreaker = nil
	parseData.lastColor = nil
	parseData.parsed = {}

	function parseData.Append(...)
		for _, val in ipairs({...})do
			local lastVal = parseData.parsed[#parseData.parsed]
			
			if isstring(lastVal) and isstring(val) then
				parseData.parsed[#parseData.parsed] = lastVal..val
				continue
			elseif IsColor(lastVal) and IsColor(val) then
				parseData.parsed[#parseData.parsed] = val
				parseData.lastColor = val
				continue
			end

			if IsColor(val) then
				if val ~= parseData.lastColor then
					parseData.lastColor = val
				else
					continue
				end
			end

			table.insert(parseData.parsed, val)
		end
	end

	while text ~= "" and text ~= nil do
		for _, data in ipairs(parsers) do
			for patternId, pattern in ipairs(data[1]) do
				local matches = {text:match("^("..pattern..")")}

				if #matches ~= 0 then
					local result = data[2](parseData, text, patternId, unpack(matches))
					if result then
						text = (isstring(result) and result or text:sub(#matches[1]+1))
						goto endof
					end
				end
			end
		end
		
		::endof::
	end

	if dontPrint then return parseData.parsed end
	repeat MsgC(table.remove(parseData.parsed, 1), table.remove(parseData.parsed, 1)) until #parseData.parsed == 0
	Msg("\n")
end

local COMMENT	= Color(101, 115, 126)
local NEUTRAL	= Color(192, 197, 206)
local STRING	= Color(163, 190, 140)
local GLOBAL 	= Color(150, 181, 180)
local NUMBER 	= Color(208, 135, 112)
local KEYWORD	= Color(180, 142, 173)
local FUNCTION 	= Color(143, 161, 179)
local CSTYLE	= Color(191, 97,  106)

registerParser("!!READ%((.-),(.-),(.-)%)!!", function(parseData, text, id, match, file, first, last)
	if SERVER then return lutils.prettyprint.stringify.ReadFunction(file, tonumber(first), tonumber(last)) end
end)

registerParser("!!CLR%((.-),(.-),(.-),(.-)%)!!", function(parseData, text, id, match, red, green, blue, alpha)
	local clr = Color(tonumber(red) or 0, tonumber(green) or 0, tonumber(blue) or 0, tonumber(alpha) or 255)
	parseData.Append(clr, "█")
	return true
end)

registerParser(".", function(parseData, text, id, match)
	if parseData.commentBreaker then
		local result = text:match("^"..parseData.commentBreaker)

		if result then
			parseData.Append(result, ColorRand())
			parseData.commentBreaker = nil

			return text:sub(#result+1)
		else
			parseData.Append(COMMENT, match)
			return true
		end

	elseif parseData.stringBreaker then
		local result = text:match("^"..parseData.stringBreaker)
		if result and parseData.lastChar ~= [[\]] then
			parseData.Append(result, ColorRand())
			parseData.stringBreaker = nil
			parseData.lastChar = nil

			return text:sub(#result+1)
		else
			parseData.Append(STRING, match)
			parseData.lastChar = match
			return true
		end

	end
end)

registerParser({"%-%-%[(=-)%[", "%-%-", "//", "/%*"}, function(parseData, text, id, match, equals)
	if id == 1 then
		parseData.commentBreaker = "]"..equals.."]"
	elseif id == 2 or id == 3 then
		parseData.commentBreaker = "\n"
	elseif id == 4 then
		parseData.commentBreaker = "%*/"
	end
	
	parseData.Append(COMMENT, match)
	return true
end)

registerParser({"%[(=-)%[", "\"", "'"}, function(parseData, text, id, match, equals)
	if id == 1 then
		parseData.stringBreaker = "]"..equals.."]"
	elseif id == 2 then
		parseData.stringBreaker = "\""
	elseif id == 3 then
		parseData.stringBreaker = "'"
	end

	parseData.Append(STRING, match)
	return true
end)

registerParser("function(.-)%((.-)%)", function (parseData, text, id, match, name, arguments)
	parseData.Append(KEYWORD, "function")

	for char in name:gmatch(".") do
		parseData.Append((char:match("%w") and FUNCTION or NEUTRAL), char)
	end

	parseData.Append(NEUTRAL, "("..arguments..")")
	return text:sub(#match+1)
end)

registerParser({"0b[01]+", "0x[0-9a-fA-F]+", "[0-9]+%.[0-9]*e[-+]?[0-9]+%.[0-9]*", "[0-9]+%.[0-9]*e[-+]?[0-9]+", "[0-9]+%.[0-9]*", "[0-9]+e[-+]?[0-9]+%.[0-9]*", "[0-9]+e[-+]?[0-9]+", "[0-9]+"}, function(parseData, text, id, match)
	parseData.Append(NUMBER, match)
	return true
end)

local keywordColors = {}
for _, v in pairs({"if", "then", "else", "elseif", "end", "while", "for", "in", "do", "break", "repeat", "until", "return", "continue", "function", "local"}) do keywordColors[v] = KEYWORD end
for _, v in pairs({"not", "and", "or"}) do  keywordColors[v] = NEUTRAL  end
keywordColors["NULL"] = CSTYLE
keywordColors["false"] = NUMBER
keywordColors["true"] = NUMBER
keywordColors["nil"] = NUMBER

registerParser("[%w_]+", function(parseData, text, id, match)
	local targetColor = (keywordColors[match] ~= nil and keywordColors[match] or GLOBAL)
	parseData.Append(targetColor, match)
	return true
end)

local cstyleOperators = {}
for _, v in pairs({"!", "!=", "||", "&&", "!"}) do cstyleOperators[v] = true end

registerParser("%p+", function(parseData, text, id, match)
	if cstyleOperators[match] then
		parseData.Append(CSTYLE, match)
		return true
	end
end)


registerParser("\n", function(parseData, text, id, match)
	parseData.Append(ColorRand(), match)
	return true
end)

registerParser(".", function(parseData, text, id, match)
	parseData.Append(NEUTRAL, match)
	return true
end)