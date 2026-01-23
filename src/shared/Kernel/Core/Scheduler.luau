--!strict

local RunService = game:GetService("RunService")
local Logger = require(script.Parent.Logger)

local Scheduler = {}

export type Task = (dt: number) -> ()

export type Priority = "Input" | "Physics" | "Default" | "Late" | "UI"

local PRIORITY_ORDER: {Priority} = {"Input", "Physics", "Default", "Late", "UI"}

local _taskQueue: { [Priority]: { [string]: Task } } = {
    Input = {},
    Physics = {},
    Default = {},
    Late = {},
    UI = {}
}

function Scheduler.addTask(name: string, callback: Task, priority: Priority?)
    local p = priority or "Default"
    
    if not _taskQueue[p] then
        Logger.error("Scheduler", "Prioridade inválida: " .. tostring(p))
        return
    end

    _taskQueue[p][name] = callback
end

function Scheduler.removeTask(name: string)
    for _, group in pairs(_taskQueue) do
        if group[name] then
            group[name] = nil
            return
        end
    end
end


local function onTick(dt: number)
    debug.profilebegin("Kernel:Scheduler")
    
    for _, priorityName in ipairs(PRIORITY_ORDER) do
        local group = _taskQueue[priorityName]
        
        if next(group) == nil then continue end
        
        debug.profilebegin("Priority:" .. priorityName)
        
        for taskName, callback in pairs(group) do
            debug.profilebegin(taskName)
            
            local success, err = pcall(callback, dt)
            
            if not success then
                Logger.warn("Scheduler", string.format("Task [%s] falhou e foi removida: %s", taskName, tostring(err)))
                group[taskName] = nil 
            end
            
            debug.profileend()
        end
        
        debug.profileend()
    end
    
    debug.profileend()
end

if RunService:IsClient() then
    RunService.RenderStepped:Connect(onTick)
else
    RunService.Heartbeat:Connect(onTick)
end

return table.freeze(Scheduler)