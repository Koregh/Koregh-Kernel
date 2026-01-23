--!strict
local Janitor = {}
Janitor.__index = Janitor

type Destructible = 
    RBXScriptConnection | 
    Instance | 
    { Destroy: (any) -> () } | 
    { Disconnect: (any) -> () } | 
    { Cleanup: (any) -> () } | 
    () -> () | 
    thread

export type Janitor = typeof(setmetatable({} :: {
    _tasks: { [any]: { Task: any, Method: string } },
    _isCleaning: boolean
}, Janitor))

function Janitor.new(): Janitor
    return setmetatable({
        _tasks = {},
        _isCleaning = false
    }, Janitor)
end

function Janitor:Add(task: Destructible, methodName: string?, key: any?)
    if key then
        self:Remove(key) 
    end

    local id = key or newproxy()
    local method = methodName

    if not method then
        if typeof(task) == "RBXScriptConnection" then
            method = "Disconnect"
        elseif typeof(task) == "function" then
            method = "run"
        elseif typeof(task) == "thread" then
            method = "cancel"
        elseif typeof(task) == "Instance" then
            method = "Destroy"
        elseif typeof(task) == "table" then
            method = task.Destroy and "Destroy" or (task.Disconnect and "Disconnect") or (task.Cleanup and "Cleanup")
        end
    end

    self._tasks[id] = { Task = task, Method = method or "Destroy" }
    return task
end

function Janitor:Remove(key: any)
    local entry = self._tasks[key]
    if entry then
        local task = entry.Task
        local method = entry.Method

        if method == "Disconnect" then task:Disconnect()
        elseif method == "Destroy" then task:Destroy()
        elseif method == "Cleanup" then task:Cleanup()
        elseif method == "cancel" then task.cancel(task)
        elseif method == "run" then task()
        elseif typeof(task) == "table" and task[method] then task[method](task)
        end
        
        self._tasks[key] = nil
    end
end

function Janitor:Cleanup()
    if self._isCleaning then return end
    self._isCleaning = true

    for key, _ in pairs(self._tasks) do
        self:Remove(key)
    end

    self._tasks = {}
    self._isCleaning = false
end

function Janitor:Destroy()
    self:Cleanup()
    setmetatable(self, nil)
end

return Janitor