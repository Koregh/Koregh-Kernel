--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(ReplicatedStorage.Shared.Kernel.Core)
local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)

local ServerBootstrap = {}

local SYSTEMS_LOAD_ORDER = {
    "ProfileSystem",   -- 1º Carrega os dados (Database)
    "PlayerSystem",    -- 2º Gerencia a entrada/saída e personagens
    "EconomySystem",   -- 3º Depende dos dados estarem carregados
    "AntiCheatSystem"  -- 4º Monitora tudo
}

function ServerBootstrap.init()
    print("[SERVER] Iniciando Bootstrap...")
    
    Core:Start(script.Parent.Parent.Systems)
    NetworkKernel.Init(Core.Logger)
    
    local systemsFolder = script.Parent.Parent.Systems
    
    for _, systemName in ipairs(SYSTEMS_LOAD_ORDER) do
        local module = systemsFolder:FindFirstChild(systemName)
        if module and module:IsA("ModuleScript") then
            local success, system = pcall(require, module)
            
            if success then
                if type(system) == "table" and system.Start then
                    task.spawn(function()
                        system.Start()
                    end)
                end
                print(`[SERVER] Sistema Carregado: {systemName}`)
            else
                warn(`[SERVER] Falha ao carregar sistema {systemName}: {system}`)
            end
        end
    end
    
    print("[SERVER] Bootstrap completo. Todos os sistemas operacionais.")
end

return ServerBootstrap