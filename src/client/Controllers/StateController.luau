--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)

local StateController = {}

-- Estado agora é dinâmico e tipado
local _state: {[string]: any} = {}

-- Sinal universal: (categoria, novo_valor, valor_antigo)
StateController.Changed = Signal.new()

-- [API DE REGISTRO]
-- Permite que outros scripts definam o que deve existir no estado inicial
function StateController.RegisterCategory(name: string, defaultValue: any)
	if _state[name] ~= nil then return end
	_state[name] = defaultValue
end

function StateController.Start()
	-- Registro automático via Network
	NetworkKernel.RegisterChannel("UpdateState", function(category: string, newData: any)
		StateController.Set(category, newData)
	end)

	-- Busca inicial segura
	task.spawn(function()
		local fullState = NetworkKernel.Invoke("GetInitialState")
		if typeof(fullState) == "table" then
			for category, data in pairs(fullState) do
				StateController.Set(category, data)
			end
		end
	end)
end

-- [GETTERS]
function StateController.Get(category: string): any
	return _state[category]
end

-- [SETTERS]
function StateController.Set(category: string, newData: any)
	local oldData = _state[category]
	
	-- No modo Staff, usamos table.freeze para garantir que o resto do 
	-- código não altere o estado na mão (apenas leitura)
	if typeof(newData) == "table" then
		table.freeze(newData)
	end
	
	_state[category] = newData
	
	-- Passamos o dado antigo também, útil para UIs que fazem animação de barra
	StateController.Changed:Fire(category, newData, oldData)
end

return StateController