--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThreadManager = require(ReplicatedStorage.Shared.Kernel.Utils.ThreadManager)
local Logger = require(ReplicatedStorage.Shared.Kernel.Core.Logger)

local LoopService = {}

type TaskEntry = {
	Name: string,
	Interval: number,
	LastUpdate: number,
	Callback: (dt: number) -> nil
}

local TaskPool = {
	Heartbeat = {} :: {TaskEntry},
	RenderStepped = {} :: {TaskEntry}
}


function LoopService:Add(name: string, connType: "Heartbeat" | "RenderStepped", interval: number, callback: (dt: number) -> nil)
	if connType == "RenderStepped" and RunService:IsServer() then 
		Logger.warn("LoopService", `Tentativa de usar RenderStepped no Server para: {name}`)
		return 
	end
	
	self:Remove(name)
	
	table.insert(TaskPool[connType], {
		Name = name,
		Interval = interval or 0,
		LastUpdate = os.clock(),
		Callback = callback
	})
end

function LoopService:Remove(name: string)
	for _, list in pairs(TaskPool) do
		for i, task in ipairs(list) do
			if task.Name == name then
				table.remove(list, i)
				return
			end
		end
	end
end

local function StartMasterLoop(connType: string)
	local event = RunService[connType] :: RBXScriptSignal
	
	event:Connect(function(dt: number)
		debug.profilebegin("KernelLoop:" .. connType)
		
		local now = os.clock()
		local tasks = TaskPool[connType]
		
		for i = #tasks, 1, -1 do
			local task = tasks[i]
			
			if now - task.LastUpdate >= task.Interval then
				local elapsed = now - task.LastUpdate
				task.LastUpdate = now
				
				local success, err = pcall(task.Callback, elapsed)
				if not success then
					Logger.error("LoopService", `Falha na tarefa '{task.Name}': {err}`)
				end
			end
		end
		
		debug.profileend()
	end)
end

function LoopService:Init()
	StartMasterLoop("Heartbeat")
	
	if RunService:IsClient() then
		StartMasterLoop("RenderStepped")
	end
	
	Logger.success("LoopService", "Sistema de Master Loop (Puro) inicializado.")
end

return LoopService