--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Utils = ReplicatedStorage.Shared.Kernel.Utils
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)
local Janitor = require(Utils.Janitor)

local InputController = {}
local _janitor = Janitor.new()
local Logger: any = nil

InputController.ActionStarted = Signal.new() 
InputController.ActionEnded = Signal.new()  

local _actionMap = {
	Jump = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA},
	Interact = {Enum.KeyCode.E, Enum.KeyCode.ButtonX},
	Attack = {Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2},
	Dash = {Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1}
}

local _activeActions = {}

function InputController._setLogger(newLogger: any)
	Logger = newLogger
end

function InputController.OnInit()
	UserInputService.InputBegan:Connect(InputController._handleInput)
	UserInputService.InputEnded:Connect(InputController._handleInput)
	
	if Logger then Logger.info("Input", "Sistema de Mapeamento de Input carregado.") end
end

function InputController._handleInput(input: InputObject, processed: boolean)
	if processed then return end
	
	for actionName, keys in pairs(_actionMap) do
		for _, key in ipairs(keys) do
			if input.KeyCode == key or input.UserInputType == key then
				
				if input.UserInputState == Enum.UserInputState.Begin then
					_activeActions[actionName] = tick()
					InputController.ActionStarted:Fire(actionName)
				
				elseif input.UserInputState == Enum.UserInputState.End then
					local pressDuration = tick() - (_activeActions[actionName] or tick())
					_activeActions[actionName] = nil
					InputController.ActionEnded:Fire(actionName, pressDuration)
				end
				
				return
			end
		end
	end
end

function InputController.IsActionActive(actionName: string): boolean
	return _activeActions[actionName] ~= nil
end

return InputController