--!strict
local NetworkContracts = {}
local _contracts: { [string]: { (any) -> (boolean, string?) } } = {}

function NetworkContracts.Add(channelName: string, schema: { (any) -> (boolean, string?) })
    if _contracts[channelName] then
       return
    end
    _contracts[channelName] = schema
end

function NetworkContracts.Get(channelName: string)
    return _contracts[channelName]
end

function NetworkContracts.Remove(channelName: string)
    _contracts[channelName] = nil
end

return NetworkContracts