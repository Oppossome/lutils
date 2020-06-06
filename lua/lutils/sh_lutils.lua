if SERVER then util.AddNetworkString("lutils") end
local lutils = lutils.MakeNamespace("lutils")
local NETID = lutils.Enum("Print", "Send")

local function networkRequest(code, players, settings)
	if SERVER and table.HasValue(players, true) then
		lutils.Execute(code, nil, settings)
		table.RemoveByValue(players, true)
		if table.Count(players) == 0 then
			return
		end
	end

	local request = {}
	request.code = code
	request.players = {}
	request.settings = {}

	for ind, val in ipairs(players) do
		request.players[ind] = (IsEntity(val) and "_"..val:UserID() or true)
	end
	
	for ind, val in pairs(settings) do
		request.settings[ind] = (IsEntity(val) and "_"..val:UserID() or val)
	end
	
	table.RemoveByValue(players, true)
	local requestStr = util.TableToJSON(request)
	local requestComp = util.Compress(requestStr)

	net.Start("lutils")
	net.WriteUInt(NETID.Send, 3)
	net.WriteUInt(#requestComp, 16)
	net.WriteData(requestComp, #requestComp)
	net[(SERVER and "Send" or "SendToServer")](players)
end

lutils.Server.PrintSessions = {}
net.Receive("lutils", function(len, ply)
	local netId = net.ReadUInt(3)

	if netId == NETID.Send then
		local compLen = net.ReadUInt(16)
		local reqStr = util.Decompress(net.ReadData(compLen))
		local reqTbl = util.JSONToTable(reqStr)
		local players, settings = {}, {}

		for ind, val in ipairs(reqTbl.players) do
			if isstring(val) then
				local matched = tonumber(val:match("_(%d+)"))
				players[ind] = (matched and Player(matched) or true)
			else
				players[ind] = val
			end
		end

		for ind, val in pairs(reqTbl.settings) do
			if isstring(val) then
				local matched = tonumber(val:match("_(%d+)"))
				settings[ind] = (matched and Player(matched) or val)
			else
				settings[ind] = val
			end
		end

		if SERVER then
			local newPlayers = hook.Run("CanLuaTarget", ply, players)
			if istable(newPlayers) then players = newPlayers end
			if not newPlayers then return end
			settings.Who = ply
		end

		local targets = SERVER and players or nil
		lutils.Execute(reqTbl.code, targets, settings)
	elseif netId == NETID.Print and SERVER then
		local sessId = net.ReadUInt(16)
		local sess = lutils.PrintSessions[sessId]

		if sess and sess[ply] then
			if table.Count(sess) == 1 then
				lutils.PrintSessions[sessId] = nil
			else
				sess[ply] = nil
			end

			MsgC(Color(247, 188, 126), string.format("\n[%s (%s)]\n", ply:Name(), ply:SteamID()))

			for i = 1, 15 do
				local compLen = net.ReadUInt(16)
				if compLen == 0 then break end
				local printStr = util.Decompress(net.ReadData(compLen))
				lutils.colorify(printStr)
			end
		end
	elseif netId == NETID.Print then
		local msgTbl = net.ReadTable()
		chat.AddText(unpack(msgTbl))
	end
end)

function lutils.Server.BroadcastMessage(...)
	net.Start("lutils")
	net.WriteUInt(NETID.Print, 3)
	net.WriteTable({...})
	net.Broadcast()
end

lutils.Stages = lutils.Enum("Before", "After")
local function buildfenv(upvalues)
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

function lutils.Execute(code, players, settings)
	if istable(players) then return networkRequest(code, players, settings) end
	local strCaller = (settings.Who and string.format("[%s]", settings.Who:Name()) or "[lutils]")
	local func = CompileString(code, strCaller, false)
	
	if IsValid(settings.Who) then
		local alert = string.format("[Running lua from %s (%s)]\n", settings.Who:Name(), settings.Who:SteamID())
		MsgC(Color(247, 188, 126), alert)
	end

	if isfunction(func) then
		local upvalues = {}
		hook.Run("LuaExecute", lutils.Stages.Before, settings, upvalues)
			setfenv(func, buildfenv(upvalues))
			
			local succ, rets = pcall(function() return tinylua.pack(func()) end)
			if not succ then ErrorNoHalt(rets) return end
		hook.Run("LuaExecute", lutils.Stages.After, settings, upvalues, rets)
		return rets.unpack()
	else
		ErrorNoHalt(func)
	end
end

function lutils.Server.PrintSession(players)
	if #players <= 1 and players[1] == true then return true end
	local plys = {}
	for _, ply in pairs(players) do
		if IsEntity(ply) then
			plys[ply] = true
		end
	end

	local sessId = math.random(1, 2^16-1)
	lutils.PrintSessions[sessId] = plys
	return sessId
end

hook.Add("LuaExecute", "lutils-print", function(stage, settings, upvalues, returns)
	if settings.PrintSess and stage == lutils.Stages.After then
		if SERVER then
			returns.iter(function(ind, val)
				local str = lutils.stringify(val)
				lutils.colorify(str)
			end)
		else
			net.Start("lutils")
			net.WriteUInt(NETID.Print, 3)
			net.WriteUInt(settings.PrintSess, 16)
			returns.iter(function(ind, val)
				local comp = util.Compress(lutils.stringify(val))
				net.WriteUInt(#comp, 16)
				net.WriteData(comp, #comp)
			end)
			net.SendToServer()
		end
	end
end)