--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)

local StateController = {}
local _state: {[string]: any} = {}

StateController.Changed = Signal.new()

function StateController.Get(path: string): any
	local segments = string.split(path, ".")
	local current = _state
	for _, segment in ipairs(segments) do
		if typeof(current) ~= "table" then return nil end
		current = current[segment]
	end
	return current
end

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (typeof(v) == "table") and deepCopy(v) or v
	end
	return copy
end

function StateController.Set(path: string, newData: any)
	local oldData = StateController.Get(path)
	
	if path == "All" then
		for k, v in pairs(newData) do
			if typeof(v) == "table" then table.freeze(v) end
			_state[k] = v
		end
	else
		local keys = string.split(path, ".")
		local category = keys[1]
		
		local fullCategoryData = deepCopy(_state[category] or {})
		local current = fullCategoryData
		
		for i = 2, #keys - 1 do
			if not current[keys[i]] then current[keys[i]] = {} end
			current = current[keys[i]]
		end
		
		current[keys[#keys]] = newData
		table.freeze(fullCategoryData)
		_state[category] = fullCategoryData
	end
	
	StateController.Changed:Fire(path, newData, oldData)
end

function StateController.Start()
	NetworkKernel.RegisterChannel("UpdateState", function(path: string, newData: any)
		StateController.Set(path, newData)
	end)

	task.spawn(function()
		local initial = NetworkKernel.Invoke("GetInitialState")
		if initial then StateController.Set("All", initial) end
	end)
end

return StateController