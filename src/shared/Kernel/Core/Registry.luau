--!strict

local Logger = require(script.Parent.Logger)

local Registry = {}

export type ManagedSystem = {
    OnInit: (self: any) -> (),
    OnStart: (self: any) -> (),
    OnUpdate: ((self: any, dt: number) -> ())?,
    Context: any,
    [any]: any
}

export type StaticModule = { [any]: any }

type RegistryImpl = {
    registerSystem: (self: RegistryImpl, name: string, instance: ManagedSystem) -> (),
    registerModule: (self: RegistryImpl, name: string, instance: StaticModule) -> (),
    get: (self: RegistryImpl, name: string) -> any,
    expect: (self: RegistryImpl, name: string, timeout: number?) -> any,
    _getManagedSystems: (self: RegistryImpl) -> { [string]: ManagedSystem }
}

local _systems: { [string]: ManagedSystem } = {}
local _modules: { [string]: StaticModule } = {}
local _waiting: { [string]: { thread } } = {}

local function _resumeWaiting(name: string, instance: any)
    if _waiting[name] then
        for _, thread in ipairs(_waiting[name]) do
            task.spawn(thread, instance)
        end
        _waiting[name] = nil
    end
end


function Registry:registerSystem(name: string, instance: ManagedSystem)
    if _systems[name] or _modules[name] then 
        Logger.error("Registry", "Colisão de nome detectada no Sistema: " .. name)
    end
    
    _systems[name] = instance
    _resumeWaiting(name, instance)
    Logger.info("Registry", "Sistema registrado com sucesso: " .. name)
end

function Registry:registerModule(name: string, instance: StaticModule)
    if _systems[name] or _modules[name] then 
        Logger.error("Registry", "Colisão de nome detectada no Módulo: " .. name)
    end

    _modules[name] = instance
    _resumeWaiting(name, instance)
    Logger.info("Registry", "Módulo estático registrado: " .. name)
end

function Registry:get(name: string): any
    local resource = _systems[name] or _modules[name]
    if not resource then
        Logger.error("Registry", "Recurso solicitado não encontrado: " .. name)
    end
    return resource
end


function Registry:expect(name: string, timeout: number?): any
    local resource = _systems[name] or _modules[name]
    if resource then return resource end

    local thread = coroutine.running()
    _waiting[name] = _waiting[name] or {}
    table.insert(_waiting[name], thread)

    if timeout then
        task.delay(timeout, function()
            if _waiting[name] then

                Logger.warn("Registry", string.format("Timeout aguardando por '%s'. Verifique se o arquivo existe no Rojo.", name))
            end
        end)
    end

    return coroutine.yield()
end

function Registry:_getManagedSystems(): { [string]: ManagedSystem }
    return _systems
end


local Interface: RegistryImpl = setmetatable({} :: any, {
    __index = Registry,
    __newindex = function() error("[REGISTRY]: Memória Protegida - Use registerSystem/Module", 2) end,
})

return table.freeze(Interface)