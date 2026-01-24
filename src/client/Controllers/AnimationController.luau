--!strict
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Shared.Kernel.Utils.Janitor) 

local AnimationController = {}

local _player = Players.LocalPlayer
local _library = ReplicatedStorage:WaitForChild("AnimationLibrary")
local _janitor = Janitor.new()

local _tracks: {[string]: AnimationTrack} = {}
local _animator: Animator? = nil
local _character: Model? = nil

local Logger = nil 

function AnimationController.Init()
	
	_player.CharacterAdded:Connect(function(newChar)
		AnimationController.SetupCharacter(newChar)
	end)

	if _player.Character then
		AnimationController.SetupCharacter(_player.Character)
	end
    
end

function AnimationController.SetupCharacter(char: Model)
	_janitor:Cleanup() 
	table.clear(_tracks)

	_character = char
	local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid
	_animator = humanoid:WaitForChild("Animator", 10) :: Animator

	if not _animator then 
		return 
	end

	local animations = _library:GetChildren()
	
	for _, anim in animations do
		if anim:IsA("Animation") then
			local success, track = pcall(function()
				return (_animator :: Animator):LoadAnimation(anim)
			end)
            
			if success and track then
				_tracks[anim.Name] = track
				_janitor:Add(track, "Destroy") 
			end
		end
	end

	_janitor:Add(humanoid.Died:Connect(function()
		_janitor:Cleanup()
	end), "Disconnect")
    
end

function AnimationController.Play(name: string, fadeTime: number?, weight: number?, speed: number?)
	local track = _tracks[name]
	if not track or not _character or not _character.Parent then 
		return 
	end
	
	track:Play(fadeTime or 0.1, weight or 1, speed or 1)
	return track
end

function AnimationController.Stop(name: string, fadeTime: number?)
	local track = _tracks[name]
	if track then track:Stop(fadeTime or 0.1) end
end

return AnimationController