--!strict
local Guard = {}

type Validator = (value: any) -> boolean
export type Schema = { [string | number]: Validator | Schema }

local FrameworkLogger: any = nil

function Guard._setLogger(logger: any)
    FrameworkLogger = logger
end

Guard.String = function(v) return typeof(v) == "string" end
Guard.Number = function(v) return typeof(v) == "number" and v == v end -- v == v evita NaN
Guard.Boolean = function(v) return typeof(v) == "boolean" end
Guard.Table = function(v) return typeof(v) == "table" end

Guard.Vector3 = function(v) return typeof(v) == "Vector3" end
Guard.Vector2 = function(v) return typeof(v) == "Vector2" end
Guard.CFrame = function(v) return typeof(v) == "CFrame" end
Guard.Color3 = function(v) return typeof(v) == "Color3" end

Guard.Instance = function(className: string)
    return function(v) 
        return typeof(v) == "Instance" and (className == "Instance" or v:IsA(className)) 
    end
end

Guard.Array = function(validator: Validator)
    return function(v)
        if typeof(v) ~= "table" then return false end
        for i, val in ipairs(v) do
            if not validator(val) then return false end
        end
        return true
    end
end

function Guard.Check(data: any, schema: Schema): (boolean, string?)
    if typeof(data) ~= "table" then 
        return false, "Data is not a table (got " .. typeof(data) .. ")" 
    end

    for key, validator in pairs(schema) do
        local value = data[key]
        
        if typeof(validator) == "table" then
            local ok, err = Guard.Check(value, validator :: Schema)
            if not ok then return false, string.format("[%s].%s", tostring(key), err) end
        elseif typeof(validator) == "function" then
            if not (validator :: Validator)(value) then
                return false, string.format("Invalid field: %s (expected %s, got %s)", 
                    tostring(key), "valid type", typeof(value))
            end
        end
    end

    return true, nil
end

function Guard.Wrap(schema: Schema, callback: (...any) -> ())
    return function(...)
        local args = {...}
        local ok, err = Guard.Check(args, schema)
        
        if ok then
            return callback(...)
        else
            local errorMsg = string.format("Security Violation: %s", err or "Unknown error")
            
            if FrameworkLogger then
                FrameworkLogger.warn("Guard", errorMsg)
            else
                warn(string.format("[GUARD_CRITICAL]: %s", errorMsg))
            end
        end
    end
end

return table.freeze(Guard)