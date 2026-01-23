--!strict
local Promise = {}
Promise.__index = Promise

export type Status = "Pending" | "Fulfilled" | "Rejected"

type PromiseObject = {
	_status: Status,
	_values: {any},
	_error: any,
	_queuedHandlers: {any},
}

function Promise.new(executor: (resolve: (...any) -> (), reject: (err: any) -> ()) -> ())
	local self = setmetatable({
		_status = "Pending",
		_values = {},
		_error = nil,
		_queuedHandlers = {},
	}, Promise)

	local function resolve(...)
		if self._status ~= "Pending" then return end
		self._status = "Fulfilled"
		self._values = {...}
		self:_process()
	end

	local function reject(err)
		if self._status ~= "Pending" then return end
		self._status = "Rejected"
		self._error = err
		self:_process()
	end

	task.spawn(function()
		local success, err = pcall(executor, resolve, reject)
		if not success then reject(err) end
	end)

	return self
end

function Promise:_process()
	if self._status == "Pending" then return end

	task.spawn(function()
		for _, handler in ipairs(self._queuedHandlers) do
			if self._status == "Fulfilled" then
				if handler.onFulfilled then
					local success, result = pcall(handler.onFulfilled, unpack(self._values))
					if not success then
						handler.reject(result)
					elseif getmetatable(result) == Promise then
						result:andThen(handler.resolve, handler.reject)
					else
						handler.resolve(result)
					end
				else
					handler.resolve(unpack(self._values))
				end
			elseif self._status == "Rejected" then
				if handler.onRejected then
					local success, result = pcall(handler.onRejected, self._error)
					if not success then
						handler.reject(result)
					elseif getmetatable(result) == Promise then
						result:andThen(handler.resolve, handler.reject)
					else
						handler.resolve(result)
					end
				else
					handler.reject(self._error)
				end
			end
		end
		table.clear(self._queuedHandlers)
	end)
end

function Promise:andThen(onFulfilled: (...any) -> any, onRejected: ((any) -> any)?)
	return Promise.new(function(resolve, reject)
		table.insert(self._queuedHandlers, {
			onFulfilled = onFulfilled,
			onRejected = onRejected,
			resolve = resolve,
			reject = reject,
		})
		self:_process()
	end)
end

function Promise:catch(onRejected: (any) -> any)
	return self:andThen(nil, onRejected)
end

function Promise.all(promises: {any})
	return Promise.new(function(resolve, reject)
		local results = {}
		local completed = 0
		if #promises == 0 then return resolve({}) end
		
		for i, p in ipairs(promises) do
			p:andThen(function(...)
				results[i] = ...
				completed += 1
				if completed == #promises then resolve(results) end
			end):catch(reject)
		end
	end)
end

function Promise.resolve(...: any)
	return Promise.new(function(resolve) resolve(...) end)
end

return Promise