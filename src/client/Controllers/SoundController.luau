--!strict
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundController = {}

local DEFAULT_FADE = 0.2
local _isMuted = false
local _currentMusic: Sound? = nil

local _library = SoundService:WaitForChild("Library")
local _sfxPool: {Sound} = {}

local _allGroups: {SoundGroup} = {}

local function registerGroup(group: SoundGroup)
	if not table.find(_allGroups, group) then
		table.insert(_allGroups, group)
		group.Volume = if _isMuted then 0 else 1
	end
end

function SoundController.Start()
	local musicG = SoundService:FindFirstChild("Music") or Instance.new("SoundGroup", SoundService)
	local sfxG = SoundService:FindFirstChild("SFX") or Instance.new("SoundGroup", SoundService)
	musicG.Name = "Music"
	sfxG.Name = "SFX"
	
	registerGroup(musicG)
	registerGroup(sfxG)

	for i = 1, 15 do
		local s = Instance.new("Sound")
		s.SoundGroup = sfxG
		s.Parent = SoundService
		table.insert(_sfxPool, s)
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
		local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
			Volume = target
		})
		tween.Completed:Connect(function()
			if target <= 0 and destroyOnEnd then
				sound:Stop()
				sound:Destroy()
			end
		end)
		tween:Play()
	end
end

function SoundController.PlayMusic(name: string, loop: boolean?, customFade: number?)
	local template = _library:FindFirstChild(name) :: Sound
	if not template then return end

	local duration = if customFade ~= nil then customFade else DEFAULT_FADE

	if _currentMusic then
		handleVolume(_currentMusic, 0, duration, true)
	end

	local newMusic = template:Clone()
	newMusic.Volume = if duration > 0 then 0 else template.Volume
	newMusic.Looped = if loop ~= nil then loop else true
	
	local targetGroup = template.SoundGroup or SoundService:FindFirstChild("Music")
	newMusic.SoundGroup = targetGroup
	if targetGroup then registerGroup(targetGroup) end
	
	newMusic.Parent = SoundService
	newMusic:Play()

	if duration > 0 then
		handleVolume(newMusic, template.Volume, duration, false)
	end
	
	_currentMusic = newMusic
end

function SoundController.PlaySFX(name: string, config: {Pos: Vector3?, PitchVar: number?, GroupName: string?}?)
	if _isMuted then return end
	
	local template = _library:FindFirstChild(name) :: Sound
	if not template then return end

	local sound = table.remove(_sfxPool, 1) or Instance.new("Sound")
	
	local targetGroup
	if config and config.GroupName then
		targetGroup = SoundService:FindFirstChild(config.GroupName) or Instance.new("SoundGroup", SoundService)
		targetGroup.Name = config.GroupName
	else
		targetGroup = template.SoundGroup or SoundService:FindFirstChild("SFX")
	end
	
	if targetGroup then 
		sound.SoundGroup = targetGroup
		registerGroup(targetGroup) 
	end
		
	sound.SoundId = template.SoundId
	sound.Volume = template.Volume
	
	local var = config and config.PitchVar or 0.05
	sound.PlaybackSpeed = template.PlaybackSpeed + (math.random() * var * 2 - var)

	if config and config.Pos then
		local attach = Instance.new("Attachment", workspace.Terrain)
		attach.Position = config.Pos
		sound.Parent = attach
		sound:Play()
		task.delay(sound.TimeLength + 0.1, function()
			sound.Parent = SoundService
			attach:Destroy()
			table.insert(_sfxPool, sound)
		end)
	else
		sound.Parent = SoundService
		sound:Play()
		task.delay(sound.TimeLength + 0.1, function()
			table.insert(_sfxPool, sound)
		end)
	end
end

function SoundController.SetMute(state: boolean)
	_isMuted = state
	for _, group in _allGroups do
		group.Volume = if state then 0 else 1
	end
end

return SoundController