--!strict

local Context = {}
Context.__index = Context

export type ExecutionSide = "Server" | "Client"

export type ContextType = {
    Name: string,
    Side: ExecutionSide,
    IsStudio: boolean,
    StartTime: number,
    Metadata: { [string]: any },
    
    IsServer: (self: ContextType) -> boolean,
    IsClient: (self: ContextType) -> boolean,
    GetRuntime: (self: ContextType) -> number,
}

function Context.new(name: string): ContextType
    local RunService = game:GetService("RunService")
    
    local self = {
        Name = name,
        Side = (RunService:IsServer() and "Server" or "Client") :: ExecutionSide,
        IsStudio = RunService:IsStudio(),
        StartTime = os.clock(),
        Metadata = {},
    }

    function self:IsServer() return self.Side == "Server" end
    function self:IsClient() return self.Side == "Client" end
    function self:GetRuntime() return os.clock() - self.StartTime end

    return table.freeze(setmetatable(self, Context)) :: any
end

function Context:__tostring()
    return string.format("Context<%s:%s>", self.Name, self.Side)
end

return table.freeze(Context)