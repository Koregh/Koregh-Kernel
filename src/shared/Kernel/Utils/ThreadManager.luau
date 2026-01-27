--!strict
local ThreadManager = {}

type Logger = {
	error: (tag: string, msg: string) -> (),
	info: (tag: string, msg: string) -> (),
	warn: (tag: string, msg: string) -> ()
}

export type ThreadContext = {
	Id: number,
	Label: string,
	Owner: string,
	StartedAt: number,
	IsCancelled: () -> boolean,
}

type ThreadEntry = {
	Context: ThreadContext,
	Thread: thread,
	CancelSignal: { Value: boolean }
}

local _activeThreads: { [number]: ThreadEntry } = {}
local _logger: Logger? = nil 
local _nextId = 0

function ThreadManager._setLogger(newLogger: Logger)
	_logger = newLogger
end

local function createEntry(label: string, owner: string, t: thread): ThreadEntry
	_nextId += 1
	local currentId = _nextId
	local cancelSignal = { Value = false }
	
	local context: ThreadContext = {
		Id = currentId,
		Label = label,
		Owner = owner,
		StartedAt = os.clock(),
		IsCancelled = function() return cancelSignal.Value end
	}
	
	return {
		Context = context,
		Thread = t,
		CancelSignal = cancelSignal
	}
end

function ThreadManager.Spawn(label: string, owner: string, callback: (ctx: ThreadContext, ...any) -> (), ...: any)
	local args = { ... }
	local entryId: number
	
	local t = task.spawn(function()
		local entry = _activeThreads[entryId]
		local success, err = pcall(callback, entry.Context, table.unpack(args))
		
		if not success then
			local msg = `[{owner} / {label}] Falha: {err}`
			if _logger then _logger.error("ThreadManager", msg) else warn(msg) end
		end
		
		_activeThreads[entryId] = nil
	end)
	
	local entry = createEntry(label, owner, t)
	entryId = entry.Context.Id
	_activeThreads[entryId] = entry
	
	return entryId
end

function ThreadManager.Loop(label: string, owner: string, interval: number, callback: (ctx: ThreadContext) -> boolean)
	return ThreadManager.Spawn(label, owner, function(ctx)
		while not ctx.IsCancelled() do
			local start = os.clock()
			local success, result = pcall(callback, ctx)
			
			if not success or result == false then 
				break 
			end
			
			local elapsed = os.clock() - start
			task.wait(math.max(0, interval - elapsed))
		end
	end)
end

function ThreadManager.Stop(id: number, forceAfter: number?)
	local entry = _activeThreads[id]
	if not entry then return end
	
	entry.CancelSignal.Value = true
	
	if forceAfter then
		task.delay(forceAfter, function()
			if _activeThreads[id] == entry then
				coroutine.close(entry.Thread)
				_activeThreads[id] = nil
			end
		end)
	end
end

function ThreadManager.StopAllFromOwner(owner: string)
	for id, entry in pairs(_activeThreads) do
		if entry.Context.Owner == owner then
			ThreadManager.Stop(id, 2)
		end
	end
end

function ThreadManager.GetActiveThreads()
	local snapshot = {}
	for id, entry in pairs(_activeThreads) do
		snapshot[id] = {
			Label = entry.Context.Label,
			Owner = entry.Context.Owner,
			StartedAt = entry.Context.StartedAt
		}
	end
	return snapshot
end

return ThreadManager