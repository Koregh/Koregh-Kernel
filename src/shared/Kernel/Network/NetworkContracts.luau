--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Shared.Kernel.Security.Guard)

local NetworkContracts = {
    
    ["AttackRequest"] = {
        [1] = Guard.String,              
        [2] = Guard.Number,              
        [3] = Guard.Instance("Model"),   
    },
    
    ["EquipItem"] = {
        [1] = Guard.Number,              
        [2] = Guard.String,              
    }
}

return NetworkContracts