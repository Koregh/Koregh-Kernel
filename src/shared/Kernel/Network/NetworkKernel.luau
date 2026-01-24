--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = ReplicatedStorage.Shared.Kernel.Utils
local Network = ReplicatedStorage.Shared.Kernel.Network

local Validator = require(Network.Validator)
local Guard = require(ReplicatedStorage.Shared.Kernel.Security.Guard)
local Contracts = require(Network.NetworkContracts)
local ThreadManager = require(Utils.ThreadManager) 
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)
local Promise = require(Utils.Promise)

type ChannelEntry = {
	Callback: (...any) -> (),
	Schema: Guard.Schema?
}

local NetworkKernel = {}
local _channels: {[string]: ChannelEntry} = {}
local _middlewares: {(player: Player?, channel: string, args: {any}) -> boolean} = {}
local _gateway: RemoteEvent
local Logger: any = nil

local _outboundQueue: {{any}} = {} 
local _pendingRequests: {[number]: any} = {}
local _requestIdCounter = 0

local MAX_STRING_LEN = 1024 
local RATE_LIMIT_PER_SEC = 25 
local _playerRateLimits: {[Player]: {LastReset: number, Count: number}} = {}

-- [HELPERS]
local function isComplex(...: any): boolean
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if typeof(v) == "table" or typeof(v) == "Instance" then return true end
	end
	return false
end

local function sanitize(val: any): any
	local t = typeof(val)
	if t == "number" then
		if val ~= val or val == math.huge or val == -math.huge then return 0 end
	elseif t == "string" then
		if #val > MAX_STRING_LEN then return string.sub(val, 1, MAX_STRING_LEN) end
	elseif t == "table" then
		for k, v in pairs(val) do val[k] = sanitize(v) end
	end
	return val
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local data = _playerRateLimits[player]
	if not data or (now - data.LastReset) >= 1 then
		_playerRateLimits[player] = { LastReset = now, Count = 1 }
		return false
	end
	data.Count += 1
	return data.Count > RATE_LIMIT_PER_SEC
end

-- [CORE]
function NetworkKernel.Init(loggerModule: any?)
	Logger = loggerModule
	
	if RunService:IsServer() then
		_gateway = ReplicatedStorage:FindFirstChild("Gateway") or Instance.new("RemoteEvent")
		_gateway.Name = "Gateway"
		_gateway.Parent = ReplicatedStorage
		
		_gateway.OnServerEvent:Connect(function(player: Player, batch: any)
			if typeof(batch) ~= "table" or isRateLimited(player) then return end
			for _, packet in ipairs(batch) do
				if typeof(packet) == "table" and packet[1] and packet[2] then
					NetworkKernel._onEvent(player, packet[1], packet[2])
				end
			end
		end)

		game.Players.PlayerRemoving:Connect(function(p) _playerRateLimits[p] = nil end)

		-- RECOLOCADO: Handler de Invoke do Servidor
		NetworkKernel.RegisterChannel("__INVOKE__", function(player: Player, internalChannel: string, id: number, ...: any)
			local target = _channels[internalChannel]
			if target then
				ThreadManager.Spawn(`Invoke_{internalChannel}`, function(p, rid, ...)
					local res = {target.Callback(p, ...)}
					NetworkKernel.FireClient(p, "__RESPONSE__", rid, table.unpack(res))
				end, player, id, ...)
			end
		end)
	else
		_gateway = ReplicatedStorage:WaitForChild("Gateway") :: RemoteEvent
		_gateway.OnClientEvent:Connect(function(batch: any)
			if typeof(batch) ~= "table" then return end
			for _, packet in ipairs(batch) do
				if typeof(packet) == "table" and packet[1] and packet[2] then
					NetworkKernel._onEvent(nil, packet[1], packet[2])
				end
			end
		end)

		-- RECOLOCADO: Handler de Resposta do Cliente
		NetworkKernel.RegisterChannel("__RESPONSE__", function(id: number, ...: any)
			local signal = _pendingRequests[id]
			if signal then signal:Fire(...) end
		end)
	end

	RunService.Heartbeat:Connect(function()
		if #_outboundQueue == 0 then return end
		if not RunService:IsServer() then
			_gateway:FireServer(_outboundQueue)
		else
			_gateway:FireAllClients(_outboundQueue)
		end
		table.clear(_outboundQueue)
	end)
end

function NetworkKernel.AddMiddleware(fn: (player: Player?, channel: string, args: {any}) -> boolean)
	table.insert(_middlewares, fn)
end

function NetworkKernel.RegisterChannel(name: string, callback: (...any) -> (), schema: Guard.Schema?)
	_channels[name] = { Callback = callback, Schema = schema }
end

-- [PACKING]
function NetworkKernel.Pack(...: any): any
	if isComplex(...) then
		local args = {...}
		for i, v in ipairs(args) do args[i] = sanitize(v) end
		return args
	end

	local args = {...}
	local temp = buffer.create(1024) 
	local cursor = 0
	for _, v in ipairs(args) do
		local safe = sanitize(v) 
		local id = Validator.NamesToIds[typeof(safe)] or 10 
		buffer.writeu8(temp, cursor, id)
		cursor += 1
		local cfg = Validator.TypeIds[id]
		if cfg and cfg.Write then cursor += cfg.Write(temp, cursor, safe) end
	end
	
	if cursor == 0 then return nil end
	local final = buffer.create(cursor)
	buffer.copy(final, 0, temp, 0, cursor)
	return final
end

function NetworkKernel.Unpack(payload: any): {any}
	if typeof(payload) ~= "buffer" then 
		return (typeof(payload) == "table" and payload) or {} 
	end

	local args, cursor, bLen = {}, 0, buffer.len(payload)
	while cursor < bLen do
		local id = buffer.readu8(payload, cursor)
		cursor += 1
		local cfg = Validator.TypeIds[id]
		if cfg and cfg.Read then
			local val, read = cfg.Read(payload, cursor)
			table.insert(args, val) 
			cursor += read
		else break end
	end
	return args
end

-- [EVENT ROUTING]
function NetworkKernel._onEvent(player: Player?, channelName: string, payload: any)
	local channel = _channels[channelName]
	if not channel then return end

	local args = NetworkKernel.Unpack(payload)

	for _, middleware in ipairs(_middlewares) do
		local ok, result = pcall(middleware, player, channelName, args)
		if not ok or result == false then return end
	end

	local schema = channel.Schema or Contracts[channelName]
	if schema then
		local ok, err = Guard.Check(args, schema)
		if not ok then 
			if Logger then Logger:Warn(`[GUARD] {player or "Client"} falhou em {channelName}: {err}`) end
			return 
		end
	end

	local threadName = `Net_{channelName}`
	if RunService:IsServer() then
		ThreadManager.Spawn(threadName, channel.Callback, player, table.unpack(args))
	else
		ThreadManager.Spawn(threadName, channel.Callback, table.unpack(args))
	end
end

-- [API]
function NetworkKernel.Send(channelName: string, ...: any)
	table.insert(_outboundQueue, {channelName, NetworkKernel.Pack(...)})
end

function NetworkKernel.Invoke(channelName: string, ...: any): ...any
	_requestIdCounter += 1
	local id = _requestIdCounter
	local signal = Signal.new()
	_pendingRequests[id] = signal
	
	NetworkKernel.Send("__INVOKE__", channelName, id, ...)
	
	local res = {signal:Wait(10)}
	_pendingRequests[id] = nil
	return table.unpack(res)
end

function NetworkKernel.Async(channelName: string, ...: any)
	local args = {...}
	local count = select("#", ...)
	return Promise.new(function(res, rej)
		local data = {NetworkKernel.Invoke(channelName, table.unpack(args, 1, count))}
		if #data > 0 then res(table.unpack(data)) else rej("Timeout") end
	end)
end

function NetworkKernel.FireClient(player: Player, channelName: string, ...: any)
	if not _gateway then return end
	_gateway:FireClient(player, {{channelName, NetworkKernel.Pack(...)}})
end

function NetworkKernel.FireAll(channelName: string, ...: any)
	if not _gateway then return end
	_gateway:FireAllClients({{channelName, NetworkKernel.Pack(...)}})
end

return NetworkKernel