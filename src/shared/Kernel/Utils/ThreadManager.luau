--!strict
local ThreadManager = {}
local _activeThreads = {}
local Logger: any = nil 

function ThreadManager._setLogger(newLogger: any)
	Logger = newLogger
end

function ThreadManager.Spawn(label: string, callback: (...any) -> (), ...: any)
	local args = {...}
	
	local thread = task.spawn(function()
		local success, err = pcall(callback, unpack(args))
		
		if not success then
			if Logger then
				Logger.error("ThreadManager", `Falha na thread [{label}]: {err}`)
			else
				warn(`[THREAD ERROR] ({label}): {err}`)
			end
		end
	end)
	
	_activeThreads[thread] = label
	
	task.spawn(function()
		while coroutine.status(thread) ~= "dead" do
			task.wait(1)
		end
		_activeThreads[thread] = nil
	end)
	
	return thread
end

function ThreadManager.Loop(label: string, interval: number, callback: () -> boolean)
	return ThreadManager.Spawn(label, function()
		while true do
			local success, shouldContinue = pcall(callback)
			
			if not success or shouldContinue == false then 
				if not success and Logger then
					Logger.error("ThreadManager", `Loop [{label}] interrompido por erro: {shouldContinue}`)
				end
				break 
			end
			task.wait(interval)
		end
	end)
end

function ThreadManager.GetActiveThreads()
	return _activeThreads
end

return ThreadManager