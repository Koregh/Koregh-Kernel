--!strict
local Selector = {}

function Selector.view(state: any, path: string)
	local keys = string.split(path, ".")
	local current = state
	
	for _, key in ipairs(keys) do
		if typeof(current) ~= "table" then return nil end
		current = current[key]
	end
	
	return current
end

return Selector