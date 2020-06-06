lutils.Contexts = {["SERVER"] = 0, ["CLIENT"] = 1, ["SHARED"] = 3, ["SELF"] = 4}

local cmds = {
	["pm2"] = {lutils.Contexts.SELF, true},
	["pm"]	= {lutils.Contexts.SELF, true},
	["lm"]	= {lutils.Contexts.SELF, false},
	["p"]	= {lutils.Contexts.SERVER, true},
	["l"]	= {lutils.Contexts.SERVER, false},
	["ps"]	= {lutils.Contexts.SHARED, true},
	["ls"]	= {lutils.Contexts.SHARED, false},
	["psc"]	= {lutils.Contexts.CLIENT, true},
	["lsc"]	= {lutils.Contexts.CLIENT, false},
}

local function processBody(ply, context, body, isPrinting)
	if context == lutils.Contexts.CLIENT then
		local tStr, code = body:match("^(.-),(.+)")
		local targs = tinylua.FindEntity(tStr, ply)
		local results = {}

		for _, ent in pairs((istable(targs) and targs or {targs}))do
			if IsValid(ent) and ent:IsPlayer() then
				table.insert(results, ent)
			end
		end

		return results, code, tStr
	elseif context == lutils.Contexts.SERVER then
		return {true}, body, "Server"
	elseif IsValid(ply) and context == lutils.Contexts.SELF then
		return {ply}, body, "Self"
	elseif context == lutils.Contexts.SHARED then
		local targets = {true, unpack(player.GetAll())}
		return targets, body, "Shared"
	end
end

local PRINT = Color(245, 177, 212)
local BASIC = Color(174, 174, 174)
local function executeCommand(ply, msg)
	local cmd, body = msg:match("^[./#!](%w+) (.+)")
	if not body then return end

	local context, doPrint = unpack(cmds[cmd:lower()] or {})
	if context then
		local players, code, tStr = processBody(ply, context, body)
		if not players then return end

		if IsValid(ply) then
			local targets = hook.Run("CanLuaTarget", ply, players)
			if istable(targets) then players = targets end
			if not targets then return end

			lutils.BroadcastMessage(ply, "@", (doPrint and PRINT or BASIC), tStr, ": ", unpack(lutils.colorify(code, true)))
		end

		local settings = {}
		settings.Who = (IsValid(ply) and ply or nil)
		settings.PrintSess = doPrint and lutils.PrintSession(players) or nil

		if doPrint then code = tinylua.MakePrefix(code) end
		lutils.Execute(code, players, settings)
		return true
	end
end

hook.Add("PlayerSay", "lutils", executeCommand)

for cmd, cmdData in pairs(cmds) do
	if cmdData[1] ~= lutils.Contexts.SELF then
		local cmdStr = "!"..cmd
		concommand.Add(cmdStr, function(ply, _, _, argStr)
			if not IsValid(ply) then
				executeCommand(nil, cmdStr.." "..argStr)
			end
		end)
	end
end

local canLocal = GetConVar("sv_allowcslua")
hook.Add("CanLuaTarget", "lutils", function(ply, targs)
	if ply:IsFullyAuthenticated() then
		if ply:IsAdmin() or ply:IsSuperAdmin() then
			return true
		elseif canLocal:GetBool() and table.HasValue(targs, ply) then
			return {ply}
		end
	end
end)