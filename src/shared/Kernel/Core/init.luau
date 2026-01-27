--!strict

local Registry = require(script:WaitForChild("Registry"))
local Lifecycle = require(script:WaitForChild("Lifecycle"))
local Scheduler = require(script:WaitForChild("Scheduler"))
local Logger = require(script:WaitForChild("Logger"))
local Context = require(script:WaitForChild("Context"))
export type System = Registry.ManagedSystem
export type Context = Context.ContextType

local Kernel = {}

Kernel.Registry = Registry
Kernel.Lifecycle = Lifecycle
Kernel.Scheduler = Scheduler
Kernel.Logger = Logger

function Kernel:Start(folders: Instance | {Instance})
    debug.profilebegin("Kernel:Bootstrap")
    Logger.info("Kernel", "Iniciando Bootstrap sequencial...")

    local folderList: {Instance} = typeof(folders) == "Instance" and {folders} or folders :: any
    local loadCount = 0

    for _, folder in ipairs(folderList) do
        for _, mod in ipairs(folder:GetDescendants()) do
            if mod:IsA("ModuleScript") then
                local success, system = pcall(require, mod)
                
                if success then
                    Registry:registerSystem(mod.Name, system)
                    loadCount += 1
                else
                    Logger.error("Kernel", "Falha ao carregar módulo: " .. mod.Name .. " -> " .. tostring(system))
                end
            end
        end
    end

    if loadCount == 0 then
        Logger.warn("Kernel", "Nenhum sistema encontrado nas pastas fornecidas.")
    end

    local startTick = os.clock()
    
    Lifecycle.init() 
    Lifecycle.start() 

    local duration = math.floor((os.clock() - startTick) * 1000)
    Logger.success("Kernel", string.format("Sistema Online! %d sistemas carregados em %dms", loadCount, duration))
    
    debug.profileend()
end

function Kernel.get(name: string): System
    return Registry:get(name)
end

function Kernel.expect(name: string, timeout: number?): any
    return (Registry :: any):expect(name, timeout)
end

function Kernel.warn(tag: string, msg: string)
    Logger.warn(tag, msg)
end

-- Adicione esta função antes do metatable Proxy
function Kernel.append(name: string, system: any)
    if not name or not system then
        Logger.error("Kernel", "Tentativa de registrar sistema inválido (faltando nome ou tabela).")
        return
    end

    -- Registra no Registry
    Registry:registerSystem(name, system)
    
    -- Se o Kernel já deu Start, precisamos inicializar esse sistema avulso agora
    -- (Isso torna seu Kernel dinâmico, aceitando sistemas até depois do Bootstrap)
    if Lifecycle.isInitialized() then -- Supondo que você tenha esse check no Lifecycle
        if type(system) == "table" and system.Init then
            local ok, err = pcall(system.Init)
            if not ok then Logger.error("Kernel", "Erro no Init avulso de " .. name .. ": " .. err) end
        end
    end
    
    if Lifecycle.isStarted() then
        if type(system) == "table" and system.Start then
            task.spawn(function()
                local ok, err = pcall(system.Start)
                if not ok then Logger.error("Kernel", "Erro no Start avulso de " .. name .. ": " .. err) end
            end)
        end
    end

    Logger.info("Kernel", "Sistema avulso registrado: " .. name)
end

local Proxy = setmetatable({} :: any, {
    __index = Kernel,
    __newindex = function(_, key)
        error(string.format("[KERNEL_FATAL]: Tentativa de sobrescrever membro protegido '%s'.", tostring(key)), 2)
    end,
    __metatable = "Privado", 
})

return (Proxy)