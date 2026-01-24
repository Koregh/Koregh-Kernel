--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manager = require(script.Manager)
local ProfileClass = require(script.ProfileClass)
local Config = require(script.Config)
local Network = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)
local Logger = require(ReplicatedStorage.Shared.Kernel.Core.Logger) 
local ValueMirror = require(script.ValueMirror) 

local DataSystem = {}

if not shared._DataSystemProfiles then
    shared._DataSystemProfiles = {}
end
DataSystem.Profiles = shared._DataSystemProfiles
DataSystem.Version = 1

local function OnPlayerAdded(player: Player)
    local userId = tostring(player.UserId)
    Logger.info("DataSystem", `Iniciando carregamento: {player.Name}`)
    
    local success, result
    local tries = 0
    
    repeat
        success, result = Manager.UpdateAsync(player, function(d) return d end)
        if not success or result == nil then
            tries += 1
            task.wait(2)
        end
    until (success and result ~= nil) or tries >= 5

    if success and result then
        local profile = ProfileClass.new(player, result)
        profile:Reconcile(Config.TEMPLATE)
        
        DataSystem.Profiles[userId] = profile

        if Config.DEBUG_MODE then
            local folder = player:FindFirstChild("_DataDebug") or Instance.new("Folder")
            folder.Name = "_DataDebug"
            folder.Parent = player
            ValueMirror.Sync(folder, profile.Data)
        end

        Logger.success("DataSystem", `Perfil Ativo: {player.Name}.. versão {DataSystem.Version}`)
        Network.FireClient(player, "UpdateState", "All", profile.Data)
    else
        player:Kick("DATA_ERROR: Falha ao sincronizar dados.")
    end
end

function DataSystem:OnStart()

    game.Players.PlayerAdded:Connect(OnPlayerAdded)
    for _, player in ipairs(game.Players:GetPlayers()) do
        task.spawn(OnPlayerAdded, player)
    end

    game.Players.PlayerRemoving:Connect(function(player)
        local id = tostring(player.UserId)
        local profile = DataSystem.Profiles[id]
        if profile then
            self:_save(player, profile, true)
            DataSystem.Profiles[id] = nil
        end
    end)
end

function DataSystem:GetProfile(player: Player)

    Logger.info("DataSystem", "Aguardando perfil do jogador versão " .. tostring(DataSystem.Version))

    if not player then return nil end
    local id = tostring(player.UserId)
    local t = 0
    while not DataSystem.Profiles[id] and player.Parent and t < 10 do
        t += task.wait(0.1)
    end
    Logger.info("DataSystem", "Perfil carregado para " .. player.Name)
    return DataSystem.Profiles[id]
end


function DataSystem:Get(player: Player, path: string): any
    local profile = self:GetProfile(player)
    if not profile then return nil end
    
    local keys = path:split(".")
    local current = profile.Data
    for _, key in ipairs(keys) do
        if current[key] == nil then return nil end
        current = current[key]
    end
    return current
end

function DataSystem:Set(player: Player, path: string, value: any)
    local profile = self:GetProfile(player)
    if not profile then return end

    local keys = path:split(".")
    local current = profile.Data
    for i = 1, #keys - 1 do
        current = current[keys[i]]
    end
    current[keys[#keys]] = value
    
    self:_processChange(player, path, value)
end

function DataSystem:Increment(player: Player, path: string, amount: number)
    local currentVal = self:Get(player, path) or 0
    self:Set(player, path, currentVal + amount)
end

function DataSystem:Decrement(player: Player, path: string, amount: number)
    local currentVal = self:Get(player, path) or 0
    self:Set(player, path, currentVal - amount)
end

function DataSystem:ListAdd(player: Player, path: string, value: any)
    local list = self:Get(player, path)
    
    if list and type(list) == "table" then
        table.insert(list, value)
        self:_processChange(player, path, list)
    else
        Logger.error("DataSystem", `Caminho {path} não é uma lista válida para {player.Name}`)
    end
end

function DataSystem:ListRemove(player: Player, path: string, key: string, targetValue: any)
    local list = self:Get(player, path)
    if not list or type(list) ~= "table" then return end

    local foundIndex = nil
    for i, item in ipairs(list) do
        if type(item) == "table" and item[key] == targetValue then
            foundIndex = i
            break
        elseif item == targetValue then
            foundIndex = i
            break
        end
    end

    if foundIndex then
        table.remove(list, foundIndex)
        self:_processChange(player, path, list)
    end
end

function DataSystem:ListMove(player: Player, fromPath: string, toPath: string, key: string, targetValue: any)
    local listFrom = self:Get(player, fromPath)
    if not listFrom then return false end

    local itemToMove = nil
    for i, v in ipairs(listFrom) do
        if (type(v) == "table" and v[key] == targetValue) or v == targetValue then
            itemToMove = v
            table.remove(listFrom, i)
            break
        end
    end

    if itemToMove then
        self:ListAdd(player, toPath, itemToMove)
        self:_processChange(player, fromPath, listFrom) 
        return true
    end
    return false
end

function DataSystem:ListHas(player: Player, path: string, key: string, targetValue: any): boolean
    local list = self:Get(player, path)
    if not list or type(list) ~= "table" then return false end

    for _, item in ipairs(list) do
        if (type(item) == "table" and item[key] == targetValue) or item == targetValue then
            return true
        end
    end
    return false
end

function DataSystem:_processChange(player: Player, path: string, newValue: any)
    local id = tostring(player.UserId)
    local profile = DataSystem.Profiles[id]
    if not profile then return end
    
    if Config.DEBUG_MODE then
        local debugFolder = player:FindFirstChild("_DataDebug")
        if debugFolder then ValueMirror.Sync(debugFolder, profile.Data) end
    end
    
    Network.FireClient(player, "UpdateState", path, newValue)
end

function DataSystem:_save(player: Player, profile: any, release: boolean)
    Manager.UpdateAsync(player, function(old)
        if not old then return nil end
        old.Data = profile.Data
        if release then profile:Release() end
        return old
    end)
end

return DataSystem