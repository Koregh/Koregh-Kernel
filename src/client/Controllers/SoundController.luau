--!strict
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenUtils = require(ReplicatedStorage.Shared.Kernel.Utils.TweenUtils)
local Janitor = require(ReplicatedStorage.Shared.Kernel.Utils.Janitor)

local SoundController = {}
local _janitor = Janitor.new()

local DEFAULT_FADE = 0.5
local _isMuted = false
local _currentMusic: Sound? = nil
local _currentAmbience: Sound? = nil

local _library = SoundService:WaitForChild("Library")
local _sfxPool: {Sound} = {}
local _allGroups: {SoundGroup} = {}

local function registerGroup(group: SoundGroup)
	if not table.find(_allGroups, group) then
		table.insert(_allGroups, group)
		group.Volume = if _isMuted then 0 else 1
		_janitor:Add(group, "Destroy")
	end
end

function SoundController.Start()
	local musicG = SoundService:FindFirstChild("Music") or Instance.new("SoundGroup", SoundService)
	local sfxG = SoundService:FindFirstChild("SFX") or Instance.new("SoundGroup", SoundService)
	local ambG = SoundService:FindFirstChild("Ambience") or Instance.new("SoundGroup", SoundService)
	
	musicG.Name = "Music"; sfxG.Name = "SFX"; ambG.Name = "Ambience"
	
	registerGroup(musicG); registerGroup(sfxG); registerGroup(ambG)

	for i = 1, 20 do
		local s = Instance.new("Sound")
		s.SoundGroup = sfxG
		s.Parent = SoundService
		table.insert(_sfxPool, s)
		_janitor:Add(s, "Destroy")
	end
end

local function handleVolume(sound: Sound, target: number, duration: number, destroyOnEnd: boolean)
	if duration <= 0 then
		sound.Volume = target
		if target <= 0 and destroyOnEnd then
			sound:Stop()
			sound:Destroy()
		end
	else
		TweenUtils.Play(sound, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Volume = target})
			:Then(function()
				if target <= 0 and destroyOnEnd then
					sound:Stop()
					sound:Destroy()
				end
			end)
	end
end

function SoundController.PlayMusic(name: string, loop: boolean?, customFade: number?)
	local template = _library:FindFirstChild(name) :: Sound
	if not template then return end

	if _currentMusic and _currentMusic.Name == name then 
        return 
    end

	local duration = customFade or DEFAULT_FADE
	if _currentMusic then handleVolume(_currentMusic, 0, duration, true) end

	local newMusic = template:Clone()
	newMusic.Volume = if duration > 0 then 0 else template.Volume
	newMusic.Looped = if loop ~= nil then loop else true
	newMusic.SoundGroup = template.SoundGroup or SoundService:FindFirstChild("Music")
	newMusic.Parent = SoundService
	newMusic:Play()

	handleVolume(newMusic, template.Volume, duration, false)
	_currentMusic = newMusic
	_janitor:Add(newMusic, "Destroy", "CurrentMusic")
end

function SoundController.PlayAmbience(name: string, customFade: number?)
	local template = _library:FindFirstChild(name) :: Sound
	if not template then return end

	if _currentAmbience and _currentAmbience.Name == name then 
        return 
    end

	local duration = customFade or DEFAULT_FADE
	if _currentAmbience then handleVolume(_currentAmbience, 0, duration, true) end

	local newAmb = template:Clone()
	newAmb.Volume = if duration > 0 then 0 else template.Volume
	newAmb.Looped = true
	newAmb.SoundGroup = template.SoundGroup or SoundService:FindFirstChild("Ambience")
	newAmb.Parent = SoundService
	newAmb:Play()

	handleVolume(newAmb, template.Volume, duration, false)
	_currentAmbience = newAmb
	_janitor:Add(newAmb, "Destroy", "CurrentAmbience")
end

function SoundController.PlaySFX(name: string, config: {Pos: Vector3?, PitchVar: number?, GroupName: string?}?)
	if _isMuted then return end
	local template = _library:FindFirstChild(name) :: Sound
	if not template then return end

	local sound = table.remove(_sfxPool, 1) or Instance.new("Sound")
	local targetGroup = if config and config.GroupName 
		then (SoundService:FindFirstChild(config.GroupName) or Instance.new("SoundGroup", SoundService))
		else (template.SoundGroup or SoundService:FindFirstChild("SFX"))
	
	sound.SoundGroup = targetGroup
	sound.SoundId = template.SoundId
	sound.Volume = template.Volume
	
	local var = config and config.PitchVar or 0.05
	sound.PlaybackSpeed = template.PlaybackSpeed + (math.random() * var * 2 - var)

	local cleanupTarget: Instance = SoundService
	if config and config.Pos then
		local attach = Instance.new("Attachment")
		attach.Position = config.Pos
		attach.Parent = workspace.Terrain
		sound.Parent = attach
		cleanupTarget = attach
	else
		sound.Parent = SoundService
	end

	sound:Play()

	task.delay(sound.TimeLength + 0.1, function()
		if not sound:IsDescendantOf(game) then return end
		sound:Stop()
		sound.Parent = SoundService
		if cleanupTarget:IsA("Attachment") then cleanupTarget:Destroy() end
		table.insert(_sfxPool, sound)
	end)
end

function SoundController.SetMute(state: boolean)
	_isMuted = state
	for _, group in _allGroups do
		TweenUtils.Play(group, "Linear", {Volume = if state then 0 else 1})
	end
end

function SoundController.Destroy()
	_janitor:Destroy()
end

return SoundController