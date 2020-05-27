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
	elseif context == lutils.Contexts.SELF then
		return {ply}, body, "Self"
	elseif context == lutils.Contexts.SHARED then
		local targets = {true, unpack(player.GetAll())}
		return targets, body, "Shared"
	end
end

local PRINT = Color(245, 177, 212)
local BASIC = Color(174, 174, 174)
hook.Add("PlayerSay", "lutils", function(ply, msg)
	local cmd, body = msg:match("^[./#!](%w+) (.+)")
	if not cmd or not body then  return  end
	local cmdData = cmds[cmd:lower()]

	if cmdData then
		local context, isPrinting = cmdData[1], cmdData[2]

		if hook.Run("CanRunLua", ply, context) then
			local players, code, tStr = processBody(ply, context, body)
			lutils.net.BroadcastMessage(ply, "@", (isPrinting and PRINT or BASIC), tStr, ": ", unpack(lutils.colorify(code, true)))

			local settings = { ["Who"] = ply, ["printid"] = lutils.net.NewSession(players, isPrinting) }
			if isPrinting then code = tinylua.MakePrefix(code) end
			lutils.ExecuteCode(code, players, settings)
			return true
		end
	end
end)

local canLocal = GetConVar("sv_allowcslua")
hook.Add("CanRunLua", "lutils", function(ply, context)
	if ply:IsAdmin() or ply:IsSuperAdmin() then
		return true
	elseif context == lutils.Contexts.SELF and canLocal:GetBool() then
		return true
	end
end)