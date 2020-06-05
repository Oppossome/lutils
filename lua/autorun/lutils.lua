lutils = lutils or {}

do	
	local contexts = { ["Server"] = SERVER, ["Client"] = CLIENT }

	local function makeProxy(target, upvalues)
		return setmetatable(upvalues or {}, {__index = target, __newindex = target})
	end

	function lutils.MakeNamespace(strPath)
		local path = _G

		for word in strPath:gmatch("[^.]+") do
			path[word] = path[word] or {}
			path = path[word]
		end

		local upvalues = {}
		
		for name, shown in pairs(contexts) do
			upvalues[name] = makeProxy(shown and path or {})
		end

		return makeProxy(path, upvalues)
	end

	function lutils.Enum(...)
		local result = {}
		for ind, val in pairs({...})do
			result[val] = ind
		end
		return result
	end
end

local function aInclude(target)
	local fileContext = target:match("/(%a%a)_.-$")

	if (fileContext == "sh" or fileContext == "cl") and SERVER then
		AddCSLuaFile(target)
	end

	if fileContext == (SERVER and "sv" or "cl") or fileContext == "sh" then
		include(target)
	end
end

aInclude("lutils/prettify/sh_colorify.lua")
aInclude("lutils/prettify/sh_stringify.lua")
aInclude("lutils/sh_lutils.lua")
aInclude("lutils/sh_tinylua.lua")
aInclude("lutils/sv_commands.lua")

local extPath = "lutils/extensions/"
for _, file in ipairs(file.Find(extPath.."*.lua", "LUA")) do
	aInclude(extPath..file)
end