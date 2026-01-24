--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)

local CharacterController = {}

local _attributes: {[string]: number} = {}
local _flags: {[string]: boolean} = {}
local _cooldowns: {[string]: number} = {}

CharacterController.Changed = Signal.new()

function CharacterController.RegisterAttribute(name: string, initialValue: number)
    _attributes[name] = initialValue
end

function CharacterController.RegisterFlag(name: string, initialValue: boolean)
    _flags[name] = initialValue
end

function CharacterController.SetFlag(name: string, value: boolean)
    if _flags[name] == value then return end
    _flags[name] = value
    CharacterController.Changed:Fire("Flag", name, value)
end

function CharacterController.GetFlag(name: string): boolean
    return _flags[name] or false
end

function CharacterController.SetAttribute(name: string, value: number)
    if _attributes[name] == value then return end
    _attributes[name] = value
    CharacterController.Changed:Fire("Attribute", name, value)
end

function CharacterController.GetAttribute(name: string): number
    return _attributes[name] or 0
end

function CharacterController.ModifyAttribute(name: string, amount: number, min: number?, max: number?)
    local current = _attributes[name]
    if not current then return end
    
    local newValue = current + amount
    
    if min then newValue = math.max(min, newValue) end
    if max then newValue = math.min(max, newValue) end
    
    if newValue ~= current then
        _attributes[name] = newValue
        CharacterController.Changed:Fire("Attribute", name, newValue)
    end
end

function CharacterController.SetCooldown(name: string, duration: number)
    _cooldowns[name] = os.clock() + duration
end

function CharacterController.GetCooldown(name: string): number
    local endTick = _cooldowns[name] or 0
    return math.max(0, endTick - os.clock())
end

function CharacterController.CanPerform(actionName: string): boolean
    if _flags["IsBusy"] then return false end
    if _flags["CanMove"] == false then return false end
    
    if CharacterController.GetCooldown(actionName) > 0 then return false end
    

    local specificFlag = "Can"..actionName
    if _flags[specificFlag] == false then return false end
    
    return true
end

return CharacterController