--!strict
local Signal = require(script.Parent.Signal)

local EventBus = {}
local _topics: { [string]: any } = {}

local function getTopic(topicName: string)
	if not _topics[topicName] then
		_topics[topicName] = Signal.new()
	end
	return _topics[topicName]
end

function EventBus.Publish(topicName: string, ...: any)
	local signal = _topics[topicName]
	if signal then
		signal:Fire(...)
	end
end

function EventBus.Subscribe(topicName: string, handler: (...any) -> ())
	local signal = getTopic(topicName)
	return signal:Connect(handler)
end

function EventBus.Wait(topicName: string)
	local signal = getTopic(topicName)
	return signal:Wait()
end

return EventBus