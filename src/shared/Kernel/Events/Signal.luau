--!strict
local Signal = {}
Signal.__index = Signal

type Connection = {
	Disconnect: (any) -> (),
	_next: Connection?,
	_handler: (...any) -> (),
}

function Signal.new()
	return setmetatable({
		_handlerListHead = nil :: Connection?,
	}, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local connection = {
		_handler = handler,
		_next = self._handlerListHead,
		Disconnect = function(selfConn)
			if self._handlerListHead == selfConn then
				self._handlerListHead = selfConn._next
			else
				local prev = self._handlerListHead
				while prev and prev._next ~= selfConn do
					prev = prev._next
				end
				if prev then
					prev._next = selfConn._next
				end
			end
		end,
	}
	self._handlerListHead = connection
	return connection
end

function Signal:Fire(...: any)
	local item = self._handlerListHead
	while item do
		task.spawn(item._handler, ...)
		item = item._next
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal