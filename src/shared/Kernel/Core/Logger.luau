--!strict
local Logger = {}

export type LogLevel = number

local LEVELS = {
    DEBUG   = 0,
    INFO    = 1,
    SUCCESS = 2, 
    WARN    = 3,
    ERROR   = 4
}

local CURRENT_LOG_LEVEL = LEVELS.INFO 

local function format(level: string, tag: string, msg: string): string
    local timestamp = os.date("%H:%M:%S")
    return string.format("[%s] [%s] [%s] %s", timestamp, level, tag:upper(), msg)
end

function Logger.debug(tag: string, msg: string)
    if CURRENT_LOG_LEVEL <= LEVELS.DEBUG then
        print(format("DEBUG", tag, msg))
    end
end

function Logger.info(tag: string, msg: string)
    if CURRENT_LOG_LEVEL <= LEVELS.INFO then
        print(format("INFO", tag, msg))
    end
end

function Logger.success(tag: string, msg: string)
    if CURRENT_LOG_LEVEL <= LEVELS.SUCCESS then
        print(format("SUCCESS", tag, msg))
    end
end

function Logger.warn(tag: string, msg: string)
    if CURRENT_LOG_LEVEL <= LEVELS.WARN then
        warn(format("WARN", tag, msg))
    end
end

function Logger.error(tag: string, msg: string)
    local formattedMsg = format("ERROR", tag, msg)
    error(formattedMsg .. "\n" .. debug.traceback(nil, 3), 2)
end

function Logger.setLogLevel(level: LogLevel)
    CURRENT_LOG_LEVEL = math.clamp(level, 0, 4)
end

return table.freeze(Logger)