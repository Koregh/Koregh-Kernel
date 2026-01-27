--!strict

local Registry = require(script.Parent.Registry)
local Scheduler = require(script.Parent.Scheduler)
local Logger = require(script.Parent.Logger)
local Context = require(script.Parent.Context)

local Lifecycle = {}

local _isInitialized = false
local _isStarted = false

type ManagedSystem = Registry.ManagedSystem


function Lifecycle.init()
    if _isInitialized then 
        Logger.warn("Lifecycle", "Tentativa de re-inicialização bloqueada.")
        return 
    end
    
    debug.profilebegin("Kernel:Lifecycle:Init")
    Logger.info("Lifecycle", "Iniciando fase [OnInit]...")

    local systems = Registry:_getManagedSystems()
    
    for name, system in pairs(systems) do
        system.Context = Context.new(name)
        
        if system.OnInit then
            debug.profilebegin(name .. ":OnInit")
            
            local success, err = pcall(system.OnInit, system)
            
            if not success then
                Logger.error("Lifecycle", string.format("Falha crítica no OnInit do sistema [%s]: %s", name, tostring(err)))
            end
            
            debug.profileend()
        end
    end

    _isInitialized = true
    debug.profileend()
end


function Lifecycle.start()
    if _isStarted then return end
    if not _isInitialized then Lifecycle.init() end

    debug.profilebegin("Kernel:Lifecycle:Start")
    Logger.info("Lifecycle", "Iniciando fase [OnStart]...")

    local systems = Registry:_getManagedSystems()

    for name, system in pairs(systems) do
        if typeof(system.OnUpdate) == "function" then
            Scheduler.addTask(name, function(dt: number)
                system:OnUpdate(dt)
            end)
            Logger.info("Lifecycle", string.format("Sistema [%s] vinculado ao Heartbeat.", name))
        end

        if typeof(system.OnStart) == "function" then
            task.spawn(function()
                debug.profilebegin(name .. ":OnStart")
                
                local success, err = pcall(system.OnStart, system)
                
                if not success then
                    Logger.error("Lifecycle", string.format("Erro de runtime no OnStart de [%s]: %s", name, tostring(err)))
                end
                
                debug.profileend()
            end)
        end
    end

    _isStarted = true
    debug.profileend()
end

function Lifecycle.isReady(): boolean
    return _isInitialized and _isStarted
end

function Lifecycle.isInitialized(): boolean
    return _isInitialized
end

function Lifecycle.isStarted(): boolean
    return _isStarted
end

return table.freeze(Lifecycle)