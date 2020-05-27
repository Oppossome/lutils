local str = setmetatable({}, {__call = function(self, ...) return self.str(...) end})
lutils.stringify = str

local function tabOut(input, amount)
	input = tostring(input)

	local remainder = amount-#input
	local tabs = math.floor(remainder/7)
	local spaces = (remainder%7)+1

	return input..string.rep(" ",spaces)..string.rep("\t", tabs)
end

function str.Table(input, minified)
	local entries = table.Count(input)
	
	if minified or entries == 0 then
		return string.format("{} --[[ %s ]]", input)
	end

	local hasEntries = false
	local result = "{\n"
	local amount = 0

	local numInd = {}
	local funcs = {}
	local vars = {}

	for ind, val in pairs(input) do
		if not isstring(ind) then
			table.insert(numInd, ind)
			continue
		end

		local target = isfunction(val) and funcs or vars
		table.insert(target, ind)
	end

	table.sort(funcs)
	table.sort(vars)

	local maxWidth = 0
	local resultTbl = {}
	for _, tbl in pairs({numInd, funcs, vars})do
		for _, val in pairs(tbl) do
			if amount == 160 then break end
			entries = entries - 1
			amount = amount + 1

			local key = (isstring(val) and val or str(val, true))
			if tonumber(key) then key = string.format("[%s]", key) end
			table.insert(resultTbl, {key, str(input[val], true)})
			maxWidth = math.max(maxWidth, #key)
		end
	end

	for ind, data in pairs(resultTbl) do
		if ind ~= 1 then result = result..",\n" end
		local key, val = tabOut(data[1], maxWidth), data[2]
		result = result..string.format("  %s= %s", key, val)
	end

	if entries ~= 0 then
		result = result..string.format("\n  -- %s left...", entries)
	end
	

	return result.."\n}"
end

function str.Entity(input, minified)
	if minified and not IsValid(input) then return string.format("%s(NULL)", tostring(input):match("%[NULL (.-)%]")) end
	if minified and input:IsPlayer() then return string.format("player.GetById(%s) --[[ %s, %s ]]", input:EntIndex(), input:Name(), input:SteamID()) end
	if minified then return string.format("Entity(%s) --[[ %s, %s ]]", input:EntIndex(), input:GetClass(), input:GetModel() or "no model") end
	if not IsValid(input) then return tostring(input) end

	local comments = {input:GetClass(), input:GetModel() or "no model"}
	local result = ""

	if input:IsPlayer() then 
		if SERVER then table.Add(comments, {input:IPAddress()}) end
		table.Add(comments, {input:SteamID(), input:Name()}) 
	end

	for _, val in ipairs(comments) do
		result = result..string.format("-- %s\n", val)
	end

	local text = (input:IsPlayer() and "player.GetById(%s)" or "Entity(%s)")
	result = result..string.format(text.." = ", input:EntIndex())
	result = result..str.Table(input:GetTable())
	return result
end

function str.Panel(input, minified)
	if minified and not IsValid(input) then return string.format("%s(NULL)", tostring(input):match("%[NULL (.-)%]")) end
	local childrenStr = string.format("%s Children", #input:GetChildren())
	local isVisible = (input:IsVisible() and "Invisible" or "Visible")

	if minified then return string.format("{Panel: %s} --[[ %s, %s ]]", input:GetName(), isVisible, childrenStr) end

	local result = string.format("--%s\n", input:GetClassName())

	result = result..string.format("vgui.Create(\"%s\") = ", input:GetName())
	result = result..str.Table(input:GetTable())
	result = result..string.format("\n--%s\n", childrenStr)
	result = result..str.Table(input:GetChildren())

	return result	
end

local function getArgs(func)
	local args = {}

	for i = 1, 100 do
		local param = debug.getlocal(func, i)
		if param ~= nil then
			table.insert(args, param)
		else
			return args
		end
	end
end

function str.ReadFunction(fileStr, first, last)
	local fileRead = file.Read(fileStr, "GAME")
	if not fileRead then return "--File cannot be read" end
	local fileTbl = fileRead:Split("\n")
	local result = ""

	for i = first, last do
		result = result..fileTbl[i].."\n"
	end

	return result
end

function str.Function(input, minified)
	local info = debug.getinfo(input)

	if minified then
		local location = (info.short_src ~= "[C]" and string.format("%s:%s-%s", info.short_src, info.linedefined, info.lastlinedefined) or "NATIVE")

		local args = getArgs(input)
		if info.isvararg then table.insert(args, "...") end
		return string.format("function(%s)\t--[[ %s ]]", table.concat(args, ", "), location)		
	end
	
	if info.short_src == "[C]" then
		return str.Function(input, true)
	end

	local result = string.format("--[[ %s:%s-%s ]]\n", info.short_src, info.linedefined, info.lastlinedefined)
	if SERVER then
		return result..str.ReadFunction(info.short_src, info.linedefined, info.lastlinedefined)
	else
		return result..string.format("!!".."READ(%s,%s,%s)!!", info.short_src, info.linedefined, info.lastlinedefined) -- Tell the server to read it when it gets back
	end
end

function str.Vector(input)
	return string.format("Vector(%s, %s, %s)", input.x, input.y, input.z)
end

function str.Color(input)
	local numbers = string.format("%s,%s,%s,%s", input.r, input.g, input.b, input.a)
	return string.format("Color(%s) --[[!!CLR(%s)!!]]", numbers, numbers)
end

function str.str(input, minified)
	if isstring(input) then return string.format('"%s"', tostring(input)) end
	if isvector(input) then return str.Vector(input) end
	if IsColor(input) then return str.Color(input) end
	
	if isfunction(input) then return str.Function(input, minified) end
	if IsEntity(input) then return str.Entity(input, minified) end
	if ispanel(input) then return str.Panel(input, minified) end
	if istable(input) then return str.Table(input, minified) end
	
	if input == nil then return "nil" end
	return tostring(input)
end