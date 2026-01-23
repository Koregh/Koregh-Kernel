--!strict
export type Result<T, E> = {
    success: boolean,
    value: T?,
    error: E?,
    unwrap: (self: any) -> T
}

local Result = {}
local Logger: any = nil

function Result._setLogger(l) Logger = l end

function Result.ok<T>(value: T): Result<T, any>
    return {
        success = true, 
        value = value, 
        unwrap = function(self) return self.value end 
    }
end

function Result.err<E>(err: E): Result<any, E>
    return {
        success = false, 
        error = err, 
        unwrap = function(self) 
            local msg = "Tentativa de unwrap em um erro: " .. tostring(self.error)
            if Logger then Logger.error("Result", msg) end
            error(msg) 
        end 
    }
end

return Result