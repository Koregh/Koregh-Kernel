--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = require(ReplicatedStorage.Shared.Kernel.Core)
local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)

local ClientBootstrap = {}

local CONTROLLERS_LOAD_ORDER = {
    "DataController",    -- Recebe os dados do servidor
    "InputController",   -- Gerencia teclado/mouse
    "CombatController",  -- Gerencia efeitos visuais de luta
    "InterfaceController" -- Gerencia a UI (Menus, Hud)
}

function ClientBootstrap.init()
    print("[CLIENT] Iniciando Bootstrap...")

    Core:Start(script.Parent.Parent.Controllers)
    NetworkKernel.Init(Core.Logger)

    local controllersFolder = script.Parent.Parent.Controllers
    
    for _, name in ipairs(CONTROLLERS_LOAD_ORDER) do
        local module = controllersFolder:FindFirstChild(name)
        if module and module:IsA("ModuleScript") then
            local success, controller = pcall(require, module)
            if success and controller.Start then
                task.spawn(controller.Start)
                print(`✅ Controller Carregado: {name}`)
            end
        end
    end
    
    print("[CLIENT] Sistema operacional.")
end

return ClientBootstrap