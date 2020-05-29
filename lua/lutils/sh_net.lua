if SERVER then util.AddNetworkString("lutils") end
local _net = lutils.MakeNamespace("lutils.net")
local MsgID = {["Code"] = 0, ["Print"] = 1}

local function send(targets)
	if CLIENT then return net.SendToServer() end

	for ind, val in ipairs(targets) do
		if not IsEntity(val) then
			table.remove(targets, ind)
		end
	end
	
	net.Send(targets)
end

local function handleRequests(code, targets, settings)
	for ind, val in pairs(targets) do
		if (SERVER and val == true) or (CLIENT and val == LocalPlayer()) then
			lutils.ExecuteCode(code, nil, settings)
			table.remove(targets, ind)
		end
	end

	return #targets == 0
end

function _net.SendRequest(code, targets, settings)
	local settings = settings or {}
	
	if handleRequests(code, targets, settings) then
		return
	end

	local targStrTbl = {}
	for ind, val in ipairs(targets) do
		targStrTbl[ind] = (IsEntity(val) and "le_"..val:UserID() or true)
	end
	
	for ind, val in pairs(settings) do
		settings[ind] = (IsEntity(val) and "le_"..val:UserID() or val)
	end

	local dataStr = util.TableToJSON({
		["code"] = code,
		["targets"] = targStrTbl,
		["settings"] = settings
	})

	local compData = util.Compress(dataStr)

	net.Start("lutils")
		net.WriteUInt(MsgID.Code, 2)
		net.WriteUInt(#compData, 16)
		net.WriteData(compData, #compData)
	send(targets)
end

net.Receive("lutils", function(len, ply)
	local msgType = net.ReadUInt(2)

	if msgType == MsgID.Code then
		if not hook.Run("CanRunLua", ply) and SERVER then return end

		local compLen = net.ReadUInt(16)
		local compStr = util.Decompress(net.ReadData(compLen))
		local compTbl = util.JSONToTable(compStr)

		for ind, val in pairs(compTbl.targets) do
			local plyId = (isstring(val) and tonumber(val:match("le_(.+)")) or false)
			if plyId then compTbl.targets[ind] = Player(plyId) end
		end 

		for ind, val in pairs(compTbl.settings) do
			local plyId = (isstring(val) and tonumber(val:match("le_(.+)")) or false)
			if plyId then  compTbl.settings[ind] = Player(plyId) end
		end

		if SERVER then
			compTbl.settings["Who"] = ply
			_net.SendRequest(compTbl.code, compTbl.targets, compTbl.settings)
		else
			handleRequests(compTbl.code, compTbl.targets, compTbl.settings)
		end
	elseif msgType == MsgID.Print and SERVER then
		local sessId = net.ReadUInt(32)
		local session = _net.PrintSessions[sessId] or {}
		
		if session[ply] then
			MsgC(Color(247, 188, 126), string.format("[%s (%s)]\n", ply:Name(), ply:SteamID()))
			session[ply] = nil

			if table.Count(session) == 0 then
				_net.PrintSessions[sessId] = nil
			end

			for i = 1, 15 do
				local compLen = net.ReadUInt(16)
				if compLen == 0 then return end
				local compStr = util.Decompress(net.ReadData(compLen))
				lutils.colorify(compStr)
			end
		end
	elseif msgType == MsgID.Print and CLIENT then
		chat.AddText(unpack(net.ReadTable()))
	end
end)

hook.Add("LuaExecute", "lutils-print", function(stage, settings, upvalues, returns)
	if stage == lutils.Stages.After and settings.printid then
		if SERVER then
			returns.iter(function(ind, val)
				local str = lutils.stringify(val)
				lutils.colorify(str)
			end)
		else
			net.Start("lutils")
			net.WriteUInt(MsgID.Print, 2)
			net.WriteUInt(settings.printid, 32)

			returns.iter(function(ind, val)
				local str = lutils.stringify(val)
				local comp = util.Compress(str)
				
				net.WriteUInt(#comp, 16)
				net.WriteData(comp, #comp)
			end)

			net.SendToServer()
		end
	end
end)

_net.Server.PrintSessions = {}
function _net.Server.NewSession(targets, isPrinting)

	if #targets == 1 and targets[1] == true then
		return true
	else
		local sessId = math.random(1, 2^32-1)
		_net.PrintSessions[sessId] = {}

		for _, ply in ipairs(targets) do
			_net.PrintSessions[sessId][ply] = true
		end

		return sessId
	end
end

function _net.Server.BroadcastMessage(...)
	net.Start("lutils")
	net.WriteUInt(MsgID.Print, 2)
	net.WriteTable({...})
	net.Broadcast()
end