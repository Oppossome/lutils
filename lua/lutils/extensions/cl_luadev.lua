local luadev = lutils.MakeNamespace("luadev")

function luadev.RunOnClient(code, target, _)
	lutils.Execute(code, {target}, {})
end

function luadev.RunOnClients(code, _)
	lutils.Execute(code, player.GetAll(), {})
end

function luadev.RunOnShared(code, _)
	local targets = player.GetAll()
	table.insert(targets, true)
	lutils.Execute(code, targets, {})
end

function luadev.RunOnSelf(code, _)
	lutils.Execute(code, {LocalPlayer()}, {})
end

function luadev.RunOnServer(code, _)
	lutils.Execute(code, {true}, {})
end