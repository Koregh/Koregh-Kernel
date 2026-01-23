--!strict
local Channel = {}
Channel.__index = Channel

export type ChannelConfig = {
    Name: string,
    Schema: any?,
    RateLimit: number?,
}

function Channel.new(config: ChannelConfig)
    local self = setmetatable({
        _config = config,
        _callback = nil,
    }, Channel)
    return self
end

function Channel:SetCallback(callback: (...any) -> ())
    self._callback = callback
end

function Channel:_process(player: Player, ...: any)
    if not self._callback then return end
    
    self._callback(player, ...)
end

return Channel