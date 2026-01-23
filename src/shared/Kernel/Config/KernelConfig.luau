--!strict
export type Config = {
    DebugMode: boolean,
    LogLevel: number,
    Security: {
        DefaultRPS: number,
        KickOnViolation: boolean,
        LogAbuse: boolean,
    },
    Lifecycle: {
        InitTimeout: number, 
        WarningThreshold: number, 
    }
}

local RunService = game:GetService("RunService")

local KernelConfig: Config = {
    DebugMode = RunService:IsStudio(),
    
    LogLevel = RunService:IsStudio() and 0 or 1,

    Security = {
        DefaultRPS = 5,
        KickOnViolation = not RunService:IsStudio(), 
        LogAbuse = true,
    },

    Lifecycle = {
        InitTimeout = 10,
        WarningThreshold = 0.5, 
    }
}

return table.freeze(KernelConfig)