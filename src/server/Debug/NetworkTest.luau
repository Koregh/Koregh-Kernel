local NetworkDebugger = {}

function NetworkDebugger.Start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)

	NetworkKernel.AddMiddleware(function(player, channel, args)
		local argCount = #args
		print(`[TRACE] {player.Name} enviou {argCount} argumentos para o canal '{channel}'`)
		return true 
	end)

	NetworkKernel.RegisterChannel("Ping", function(player, str, num, bool, tbl)
		print("--- [DADOS RECEBIDOS] ---")
		print(`Origem: {player.Name}`)
		print(`Texto: {str} (Tipo: {typeof(str)})`)
		print(`Número: {num} (Tipo: {typeof(num)})`)
		print(`Booleano: {bool} (Tipo: {typeof(bool)})`)
		
		if typeof(tbl) == "table" then
			print(`Tabela detectada com sucesso!`)
		else
			print(`Tabela não recebida ou nula.`)
		end
	end)

	NetworkKernel.RegisterChannel("GetServerInfo", function(player)
		return "Success", {
			Time = os.time(),
			PlayerCount = #game.Players:GetPlayers(),
			Version = "1.0.5-GOLD"
		}
	end)

	print("[SERVER] Debugger atualizado e aguardando testes.")
end

return NetworkDebugger