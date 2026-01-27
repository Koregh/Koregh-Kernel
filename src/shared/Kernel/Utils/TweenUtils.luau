--!strict
local TweenService = game:GetService("TweenService")

type Preset = "Default" | "Pop" | "Smooth" | "Linear" | "Sharp"

local TweenUtils = {}

TweenUtils.Presets = {
	Default = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	Linear = TweenInfo.new(0.2, Enum.EasingStyle.Linear),
	Sharp = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
}

local TweenInstance = {}
TweenInstance.__index = TweenInstance

function TweenInstance.new(instance: Instance, info: TweenInfo, goals: {[string]: any}, janitor: any?)
	local self = setmetatable({}, TweenInstance)
	
	self._instance = instance
	self._tween = TweenService:Create(instance, info, goals)
	self._janitor = janitor
	self._connection = nil :: RBXScriptConnection?
	
	if self._janitor then
		self._janitor:Add(self._tween, "Destroy")
	end
	
	return self
end

function TweenInstance:Play()
	if self._tween and self._instance and self._instance.Parent then
		self._tween:Play()
	end
	return self
end

function TweenInstance:Then(callback: () -> ())
	if not self._tween then return self end
	
	-- Limpa conexão anterior se existir
	if self._connection then self._connection:Disconnect() end

	self._connection = self._tween.Completed:Connect(function()
		if self._connection then 
			self._connection:Disconnect()
			self._connection = nil
		end
		
		if self._instance and self._instance.Parent then
			callback()
		end
	end)
	
	if self._janitor and self._connection then
		self._janitor:Add(self._connection, "Disconnect")
	end
	
	return self
end

function TweenInstance:Cancel()
	if self._tween then
		self._tween:Cancel()
	end
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	return self
end

function TweenInstance:Destroy()
	self:Cancel()
	if self._tween then
		self._tween:Destroy()
		self._tween = nil :: any
	end
	self._instance = nil :: any
	self._janitor = nil :: any
end

function TweenUtils.Play(instance: Instance, info: Preset | TweenInfo, goals: {[string]: any}, janitor: any?)
	local tweenInfo = typeof(info) == "string" and TweenUtils.Presets[info] or info
	local wrapper = TweenInstance.new(instance, tweenInfo :: TweenInfo, goals, janitor)
	return wrapper:Play()
end

function TweenUtils.Group(tweens: {any}, onComplete: () -> ())
	local total = #tweens
	local completed = 0
	
	if total == 0 then onComplete() return end

	for _, t in ipairs(tweens) do
		t:Then(function()
			completed += 1
			if completed == total then
				onComplete()
			end
		end)
	end
end

return TweenUtils