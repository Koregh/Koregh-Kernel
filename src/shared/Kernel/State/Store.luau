--!strict
local Store = {}
Store.__index = Store

export type State = { [string]: any }
export type Action = (state: State) -> State
export type Listener = (newState: State, oldState: State) -> ()

function Store.new(initialState: State)
	local self = setmetatable({
		_state = initialState or {},
		_listeners = {},
	}, Store)
	return self
end

function Store:GetState(): State
	return self._state
end

function Store:Dispatch(actionName: string, reducer: Action)
	local oldState = self._state
	local nextState = reducer(oldState)
	
	self._state = nextState
	
	for _, listener in ipairs(self._listeners) do
		task.spawn(listener, nextState, oldState)
	end
end

function Store:Subscribe(listener: Listener)
	table.insert(self._listeners, listener)
	return function()
		local index = table.find(self._listeners, listener)
		if index then table.remove(self._listeners, index) end
	end
end

return Store