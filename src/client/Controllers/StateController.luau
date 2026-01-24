--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NetworkKernel = require(ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)

local StateController = {}

local _state: {[string]: any} = {}

StateController.Changed = Signal.new()

function StateController.RegisterCategory(name: string, defaultValue: any)
	if _state[name] ~= nil then return end
	_state[name] = defaultValue
end

function StateController.Start()
	NetworkKernel.RegisterChannel("UpdateState", function(category: string, newData: any)
		StateController.Set(category, newData)
	end)

	task.spawn(function()
		local fullState = NetworkKernel.Invoke("GetInitialState")
		if typeof(fullState) == "table" then
			for category, data in pairs(fullState) do
				StateController.Set(category, data)
			end
		end
	end)
end

function StateController.Get(category: string): any
	return _state[category]
end

function StateController.Set(category: string, newData: any)
	local oldData = _state[category]
	
	if typeof(newData) == "table" then
		table.freeze(newData)
	end
	
	_state[category] = newData
	
	StateController.Changed:Fire(category, newData, oldData)
end

return StateController