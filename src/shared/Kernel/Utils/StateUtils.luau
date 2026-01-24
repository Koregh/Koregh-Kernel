--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Shared.Kernel.Utils.Janitor)
local Logger = require(ReplicatedStorage.Shared.Kernel.Core.Logger)

local StateUtils = {}

local Caches: { [string]: {Instance} } = {}
local Janitors: { [string]: any } = {} 

function StateUtils:TrackTag(tag: string)
	if Janitors[tag] then return end 
	
	local tagJanitor = Janitor.new()
	Janitors[tag] = tagJanitor
	Caches[tag] = CollectionService:GetTagged(tag)
	
	tagJanitor:Add(CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if not table.find(Caches[tag], instance) then
			table.insert(Caches[tag], instance)
		end
	end))
	
	tagJanitor:Add(CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		local index = table.find(Caches[tag], instance)
		if index then
			table.remove(Caches[tag], index)
		end
	end))
	
	Logger.info("StateUtils", `Janitor assumiu o controle do cache da Tag: {tag}`)
end

function StateUtils:GetByTag(tag: string): {Instance}
	if not Janitors[tag] then
		self:TrackTag(tag)
	end
	return Caches[tag]
end

function StateUtils:StopTracking(tag: string)
	if Janitors[tag] then
		Janitors[tag]:Destroy() 
		Janitors[tag] = nil
		Caches[tag] = nil
		Logger.info("StateUtils", `Cache e Janitor da Tag '{tag}' foram destruídos.`)
	end
end

return StateUtils