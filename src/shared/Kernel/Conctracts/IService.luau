--!strict
local ISystem = require(script.Parent.ISystem)

export type IService = ISystem.ISystem & {
    Client: { [string]: (...any) -> ...any }?, 
    __private: { [any]: any }?, 
}

return {}