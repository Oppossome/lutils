tinylua = setmetatable({}, {__call = function(self, ...) return self.Wrap(...) end})
local INTERNAL = {}
local META = {}

local function pack(...) -- Convenient argument packer
	local len, tbl = select('#', ...), {...}

	return setmetatable(tbl, {
		__index = {
			["unpack"] = function()
				return unpack(tbl, 1, len)
			end,
			["iter"] = function(func)
				for i = 1, len do
					func(i, tbl[i])
				end
			end
		},
		__call = function(...)
			return len, tbl
		end
	})
end

local function Wrap(input)
	local key = newproxy()
	local values = {}
	local meta = {}

	for ind, val in pairs(input)do
		values[(tonumber(ind) and val or ind)] = val
	end

	for ind, val in pairs(META) do
		meta[ind] = val
	end

	meta.__metatable = {}
	return setmetatable(values, meta)
end

local function performCall(tbl, callback)
	local results = {}
	local errors = {}
	local calls = 0

	local iKey, iVal = nil, nil
	while true do
		local succ, err = pcall(function()
			while true do
				iKey, iVal = next(tbl, iKey)
				if iKey == nil then break end
				calls = calls + 1

				callback(results, iKey, iVal)
			end
		end)

		if not succ then errors[iKey] = err end
		if iKey == nil then break end
	end

	if table.Count(errors) == calls and calls ~= 0 then
		local _, error = next(errors, nil)
		MsgC(Color(235, 111, 111), "[tinylua] "..error)
	end

	local result = Wrap(results)
	getmetatable(result)["errors"] = errors
	return result
end

function META:__index(index)
	if INTERNAL[index] then
		return function(_, ...)
			return INTERNAL[index](self, ...)
		end
	end

	return performCall(self, function(results, source, ent)
		local target = ent[index]

		if isfunction(target) then
			results[source] = function(fArg, ...)
				if fArg == self then
					return target(ent, ...)
				else
					return target(fArg, ...)
				end
			end
		else
			results[source] = target
		end
	end)
end

function META:__newindex(index, value)
	performCall(self, function(results, source, ent)
		ent[index] = value
	end)
end

function META:__call(...)
	local args = pack(...)

	return performCall(self, function(results, source, ent)
		if isfunction(ent) then
			local rets = pack(ent(args:unpack()))
			if #rets ~= 1 then
				for _, ret in pairs(rets) do
					table.insert(results, ret)
				end
			else
				results[source] = rets[1]
			end
		end
	end)
end

-- Exposed Functions
tinylua.Wrap = Wrap
tinylua.pack = pack

-- INTERNAL Extensions
function tinylua.MakePrefix(input)
	if not input:match("\n") and isfunction(CompileString("return "..input, "", false)) then
		return "return "..input
	end

	return input
end

local function buildParser(input)
	if isfunction(input) then return input end
	local argStr, funcStr = input:match("(.-)->(.+)")

	if argStr and funcStr then
		local codeFull = string.format("return function(%s)\n%s\nend", argStr, tinylua.MakePrefix(funcStr))
		local funcFactory = CompileString(codeFull, "funcfactory")

		if funcFactory then
			return funcFactory()
		end
	end
end

function INTERNAL:map(input)
	local eval = buildParser(input)

	return performCall(self, function(results, source, ent)
		if not eval then
			results[source] = nil
			return
		end

		local rets = pack(eval(ent, source))
		if #rets ~= 1 then
			for _, val in pairs(rets) do
				table.insert(results, val)
			end
		else
			results[source] = rets[1]
		end
	end)
end

function INTERNAL:filter(input)
	local eval = buildParser(input)
	return performCall(self, function(results, source, ent)
		if not eval then
			results[source] = nil
			return
		end

		if eval(ent, source) then
			results[source] = ent
		end
	end)
end

function INTERNAL:flip()
	return performCall(self, function(results, source, ent)
		results[ent] = source
	end)
end

function INTERNAL:set(vars, val)
	vars = (istable(vars) and vars or {vars})
	return performCall(self, function(results, source, ent)
		for _, var in ipairs(vars) do
			ent[var] = val
		end

		results[source] = ent
	end)
end

function INTERNAL:keys()
	return performCall(self, function(results, source, ent)
		results[source] = source
	end)
end

function INTERNAL:first()
	for _, ent in pairs(self) do
		return ent
	end
end

function INTERNAL:IsValid()
	return false
end

function INTERNAL:errors()
	return (getmetatable(self).errors or {})
end

function INTERNAL:get()
	return table.ClearKeys(self)
end

-- tinylua wrapper
local allFuncs = {}

local function compareString(str1, str2)
	if #str1 > 3 and str1:lower():find(str2:lower()) then return true end
	if str1:lower():sub(1, #str2) == str2:lower() then return true end
	if str1:lower() == str2:lower() then return true end
	return false
end

function tinylua.FindEntity(input, upvalues)
	local upvalues = (IsEntity(upvalues) and tinylua.BuildUpvalues(upvalues) or (upvalues or {}))
	input = input:Trim()

	local steamId = input:match("^(STEAM%S+)")
	if steamId then return player.GetBySteamID(steamId:Trim()) end

	local tinyFunc = allFuncs[input:match("^#(%a+)")]
	if tinyFunc then return tinylua(tinyFunc(upvalues)) end

	local upvalue = upvalues[input:match("^#(%a+)")]
	if upvalue and IsEntity(upvalue) then return upvalue end

	local entIndex = input:match("^_(%d+)")
	if entIndex then return Entity(tonumber(entIndex)) end

	local teamTarget = input:match("^#(%a+)")
	if teamTarget then
		for teamId, data in pairs(team.GetAllTeams()) do
			if data.Name:lower() == teamTarget:lower() then
				return tinylua(player.GetAll()):filter(function(ply)
					return ply:Team() == teamId
				end)
			end
		end

		for _, ent in ipairs(ents.GetAll())do
			if ent:GetClass():lower() == teamTarget:lower() then
				return tinylua(ents.FindByClass(ent:GetClass()))
			end
		end
	end

	for _, group in pairs({player.GetBots(), player.GetHumans()})do
		for _, ply in pairs(group)do
			if compareString(ply:Nick(), input) then
				return ply
			end
		end
	end
end

function tinylua.BuildUpvalues(ply)
	if not IsValid(ply) then return {} end
	local upvalues, trace = {}, ply:GetEyeTrace()

	upvalues.me		= ply
	upvalues.here	= ply:GetPos()
	upvalues.veh	= ply:GetVehicle()
	upvalues.dir	= ply:GetAimVector()
	upvalues.wep	= ply:GetActiveWeapon()

	upvalues.trace	= trace
	upvalues.there  = trace.HitPos
	upvalues.length	= trace.StartPos:Distance(trace.HitPos)
	upvalues.this	= trace.Entity

	return upvalues
end

hook.Add("LuaExecute", "tinylua", function(stage, settings, upvalues)
	if not settings.NoTiny and stage == lutils.Stages.Before then
		for ind, val in pairs(tinylua.BuildUpvalues(settings.Who))do
			upvalues[ind] = val
		end

		upvalues.allof = function(class)
			if IsEntity(class) then class = class:GetClass() end
			return tinylua(ents.FindByClass(class))
		end

		table.insert(upvalues, setmetatable({}, {
			__index = function(self, index)
				local allFunc = allFuncs[index]
				if allFunc then return tinylua(allFunc(upvalues)) end

				local ent = tinylua.FindEntity(index, upvalues)
				if ent then return ent end
			end
		}))
	end
end)

allFuncs["all"]	= player.GetAll
allFuncs["bots"] = player.GetBots
allFuncs["humans"] = player.GetHumans
allFuncs["props"] = function() return ents.FindByClass("prop_physics") end
allFuncs["those"] = function(upvalues) return ents.FindInSphere(upvalues.there, 250) end
allFuncs["these"] = function(upvalues) return constraint.GetAllConstrainedEntities(upvalues.this) end

allFuncs["us"] = function(upvalues)
	local results = {}

	for _, ply in pairs(player.GetAll()) do
		if ply:GetPos():Distance(upvalues.me:GetPos()) < 1000 then
			table.insert(results, ply)
		end
	end

	return results
end

allFuncs["them"] = function(upvalues)
	local results = allFuncs.us(upvalues)
	table.RemoveByValue(results, upvalues.me)
	return results
end

allFuncs["npcs"] = function()
	local results = {}

	for _, ent in pairs(ents.GetAll()) do
		if ent:IsNPC() then
			table.insert(results, ent)
		end
	end

	return results
end