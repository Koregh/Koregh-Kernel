--!strict
local Slice = {}
Slice.__index = Slice

function Slice.new(name: string, initialState: any)
	return setmetatable({
		Name = name,
		InitialState = initialState,
		Reducers = {}
	}, Slice)
end

function Slice:AddReducer(actionName: string, callback: (state: any, payload: any) -> any)
	self.Reducers[actionName] = callback
end

return Slice