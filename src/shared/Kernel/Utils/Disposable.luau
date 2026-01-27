--!strict
local Disposable = {}
Disposable.__index = Disposable

local Logger: any = nil

type CustomDisposable = { dispose: (any) -> () }
type Task = RBXScriptConnection | Instance | (() -> ()) | CustomDisposable | any

export type DisposableFolder = {
	_tasks: { Task },
	_caches: { [string]: { [Instance]: Instance } }, 
	add: (self: DisposableFolder, task: Task) -> Task,
	bindFolder: (self: DisposableFolder, name: string, folder: Instance) -> (), 
	get: (self: DisposableFolder, name: string) -> { Instance }, 
	dispose: (self: DisposableFolder) -> (),
}

function Disposable._setLogger(l: any)
	Logger = l
end

function Disposable.new(): DisposableFolder
	return setmetatable({ 
		_tasks = {}, 
		_caches = {} 
	}, Disposable) :: any
end

function Disposable:bindFolder(name: string, folder: Instance)
	local cache = {}
	self._caches[name] = cache

	local function add(child: Instance)
		cache[child] = child
	end

	local function remove(child: Instance)
		cache[child] = nil
	end

	self:add(folder.ChildAdded:Connect(add))
	self:add(folder.ChildRemoved:Connect(remove))

	-- Popula o cache inicial
	for _, child in ipairs(folder:GetChildren()) do
		add(child)
	end
end

function Disposable:get(name: string): { Instance }
	local cache = self._caches[name]
	if not cache then return {} end

	local list = {}
	for _, item in pairs(cache) do
		table.insert(list, item)
	end
	return list
end

function Disposable:add(task: Task): Task
	table.insert(self._tasks, task)
	return task
end

function Disposable:dispose()
	local count = #self._tasks
	
	for _, task in ipairs(self._tasks) do
		taskcall(function()
			if typeof(task) == "RBXScriptConnection" then
				task:Disconnect()
			elseif typeof(task) == "Instance" then
				task:Destroy()
			elseif typeof(task) == "function" then
				task()
			elseif typeof(task) == "table" then
				local rawTask = task :: any
				if rawTask.dispose and typeof(rawTask.dispose) == "function" then
					rawTask:dispose()
				end
			end
		end)
	end
	
	if Logger and count > 0 then
		Logger.info("Disposable", string.format("Cleanup concluído: %d tarefas removidas.", count))
	end
	
	self._tasks = {}
	self._caches = {} 
end

function taskcall(callback: () -> ())
	local success, err = pcall(callback)
	if not success and Logger then
		Logger.error("Disposable", "Erro ao limpar tarefa: " .. tostring(err))
	end
end

return table.freeze(Disposable)