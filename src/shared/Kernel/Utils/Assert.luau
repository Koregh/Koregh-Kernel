--!strict
local Assert = {}
local Logger: any = nil

function Assert._setLogger(l) Logger = l end

function Assert.that(condition: any, message: string, ...: any)
    if not condition then
        local formatted = string.format(message, ...)
        
        if Logger then
            Logger.error("Assert", "Violation: " .. formatted)
        end
        
        error(string.format("[ASSERTION_FAILED] %s", formatted), 2)
    end
end

return Assert