lutils.Stages = {["Before"] = 0, ["After"] = 1}

local function buildWrapper(upvalues)
	local upTbl = {}

	for ind, val in pairs(upvalues) do
		if not tonumber(ind) then
			upTbl[ind] = val
		end
	end

	return setmetatable(upTbl, {
		__index = function(self, index)
			for _, tbl in ipairs(upvalues) do
				local val = tbl[index]
				if val then return val end
			end
			
			return _G[index]
		end,
		__newindex = _G
	})
end

local function callAndPack(input)
	return tinylua.pack(input())
end

function lutils.ExecuteCode(code, targets, settings)
	if targets ~= nil then return lutils.net.SendRequest(code, targets, settings) end
	local sessId = (settings.Who and string.format("[%s] ", settings.Who:GetName()) or "lutils")
	local compiledCode = CompileString(code, sessId, false)
	local upvalues = {}
	
	if settings.Who then 
		local message = string.format("[Running lua from %s (%s)]\n", settings.Who:Name(), settings.Who:SteamID())
		MsgC(Color(247, 188, 126), message)
	end


	if isstring(compiledCode) then
		ErrorNoHalt(compiledCode)
		return
	end

	hook.Run("LuaExecute", lutils.Stages.Before, settings, upvalues)
		setfenv(compiledCode, buildWrapper(upvalues))

		local succ, rets = pcall(callAndPack, compiledCode)
		if not succ then return ErrorNoHalt(rets) end
	hook.Run("LuaExecute", lutils.Stages.After, settings, upvalues, rets)

	return rets.unpack()
end