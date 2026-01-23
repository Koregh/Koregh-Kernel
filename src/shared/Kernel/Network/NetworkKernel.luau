--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = ReplicatedStorage.Shared.Kernel.Utils
local Network = ReplicatedStorage.Shared.Kernel.Network

local Validator = require(Network.Validator)
local Guard = require(ReplicatedStorage.Shared.Kernel.Security.Guard)
local ThreadManager = require(Utils.ThreadManager) 
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)
local Promise = require(Utils.Promise)

local NetworkKernel = {}
local _channels = {}
local _gateway: RemoteEvent
local Logger: any = nil

local _pendingRequests = {}
local _requestIdCounter = 0

-- Configurações de Segurança Sênior
local MAX_BUFFER_SIZE = 16384 -- 16KB (Proteção contra estouro de memória)
local MAX_STRING_LEN = 1024   -- Limite para strings enviadas
local RATE_LIMIT_PER_SEC = 20 -- Máximo de pacotes por segundo por jogador
local _playerRateLimits = {}  -- { [Player]: { LastReset: number, Count: number } }

-- 🛡️ Sanitização: Neutraliza valores perigosos (NaN, Infinito, Strings Gigantes)
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

function NetworkKernel._setLogger(newLogger: any)
	Logger = newLogger
end

function NetworkKernel.Init()
	if RunService:IsServer() then
		_gateway = ReplicatedStorage:FindFirstChild("Gateway") or Instance.new("RemoteEvent")
		_gateway.Name = "Gateway"
		_gateway.Parent = ReplicatedStorage
		
		_gateway.OnServerEvent:Connect(function(player: Player, channelName: string, payload: any)
			if isRateLimited(player) then
				if Logger then Logger.warn("Security", `Player {player.Name} atingiu Rate Limit!`) end
				return 
			end
			NetworkKernel._onEvent(player, channelName, payload)
		end)

		game.Players.PlayerRemoving:Connect(function(player) _playerRateLimits[player] = nil end)

		NetworkKernel.RegisterChannel("__INVOKE__", function(player: Player, internalChannel: string, id: number, ...: any)
			local targetChannel = _channels[internalChannel]
			if targetChannel then
				ThreadManager.Spawn(`Invoke_{internalChannel}`, function(p, rid, ...)
					local results = {targetChannel.Callback(p, ...)}
					NetworkKernel.FireClient(p, "__RESPONSE__", rid, unpack(results))
				end, player, id, ...)
			end
		end)
	else
		_gateway = ReplicatedStorage:WaitForChild("Gateway") :: RemoteEvent
		_gateway.OnClientEvent:Connect(function(channelName, payload)
			NetworkKernel._onEvent(nil, channelName, payload)
		end)

		NetworkKernel.RegisterChannel("__RESPONSE__", function(id: number, ...: any)
			local signal = _pendingRequests[id]
			if signal then signal:Fire(...) end
		end)
	end
	
	if Logger then Logger.info("Network", "Kernel de Rede Blindado Inicializado.") end
end

function NetworkKernel.RegisterChannel(name: string, callback: (...any) -> (), schema: Guard.Schema?)
	_channels[name] = { Callback = callback, Schema = schema }
end

function NetworkKernel.Pack(...: any): buffer
	local args = {...}
	local temp = buffer.create(1024) 
	local cursor = 0
	
	for _, v in ipairs(args) do
		local safeValue = sanitize(v) 
		local id = Validator.NamesToIds[typeof(safeValue)] or 12 
		buffer.writeu8(temp, cursor, id)
		cursor += 1
		local cfg = Validator.TypeIds[id]
		if cfg and cfg.Write then cursor += cfg.Write(temp, cursor, safeValue) end
	end
	
	local final = buffer.create(cursor)
	buffer.copy(final, 0, temp, 0, cursor)
	return final
end

function NetworkKernel.Unpack(b: buffer): {any}
	local args, cursor, bLen = {}, 0, buffer.len(b)
	while cursor < bLen do
		local id = buffer.readu8(b, cursor)
		cursor += 1
		local cfg = Validator.TypeIds[id]
		if cfg and cfg.Read then
			local val, read = cfg.Read(b, cursor)
			table.insert(args, sanitize(val)) 
			cursor += read
		end
	end
	return args
end

function NetworkKernel._onEvent(player: Player?, channelName: string, payload: any)
	if typeof(payload) == "buffer" and buffer.len(payload) > MAX_BUFFER_SIZE then
		if Logger then Logger.error("Security", `Buffer gigante de {player}: {buffer.len(payload)} bytes`) end
		return 
	end

	local channel = _channels[channelName]
	if not channel then return end

	local args = typeof(payload) == "buffer" and NetworkKernel.Unpack(payload) or {sanitize(payload)}

	if channel.Schema then
		local ok, err = Guard.Check(args, channel.Schema)
		if not ok then return end
	end

	if RunService:IsServer() then
		ThreadManager.Spawn(`Net_{channelName}`, channel.Callback, player, unpack(args))
	else
		ThreadManager.Spawn(`Net_{channelName}`, channel.Callback, unpack(args))
	end
end

function NetworkKernel.Send(channelName: string, ...: any)
	if not _gateway then return end
	_gateway:FireServer(channelName, NetworkKernel.Pack(...))
end

function NetworkKernel.Invoke(channelName: string, ...: any): ...any
	_requestIdCounter += 1
	local id = _requestIdCounter
	local responseSignal = Signal.new()
	_pendingRequests[id] = responseSignal
	
	NetworkKernel.Send("__INVOKE__", channelName, id, ...)
	
	local result = {responseSignal:Wait(10)}
	_pendingRequests[id] = nil
	return unpack(result)
end

function NetworkKernel.Async(channelName: string, ...: any)
	return Promise.new(function(resolve, reject)
		local results = {NetworkKernel.Invoke(channelName, ...)}
		if #results > 0 then resolve(unpack(results)) else reject("Timeout") end
	end)
end

function NetworkKernel.FireClient(player: Player, channelName: string, ...: any)
	if not _gateway then return end
	_gateway:FireClient(player, channelName, NetworkKernel.Pack(...))
end

function NetworkKernel.FireAll(channelName: string, ...: any)
	if not _gateway then return end
	_gateway:FireAllClients(channelName, NetworkKernel.Pack(...))
end

return NetworkKernel