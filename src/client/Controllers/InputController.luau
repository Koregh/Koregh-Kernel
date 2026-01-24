--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Utils = ReplicatedStorage.Shared.Kernel.Utils
local Signal = require(ReplicatedStorage.Shared.Kernel.Events.Signal)
local Character = require(script.Parent.CharacterController) 

local InputController = {}
local Logger: any = nil

InputController.ActionStarted = Signal.new() 
InputController.ActionEnded = Signal.new()  

local _actionMap: {[string]: {Enum.KeyCode | Enum.UserInputType}} = {}
local _activeActions: {[string]: number} = {}

function InputController._setLogger(newLogger: any)
    Logger = newLogger
end

function InputController.BindAction(actionName: string, keys: {Enum.KeyCode | Enum.UserInputType})
    _actionMap[actionName] = keys
end

function InputController.UnbindAction(actionName: string)
    _actionMap[actionName] = nil
end

function InputController.OnInit()
    UserInputService.InputBegan:Connect(InputController._handleInput)
    UserInputService.InputEnded:Connect(InputController._handleInput)
    
    InputController.BindAction("Jump", {Enum.KeyCode.Space, Enum.KeyCode.ButtonA})
    InputController.BindAction("Attack", {Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2})
    
    if Logger then Logger.info("Input", "Sistema de Mapeamento Extensível carregado.") end
end

function InputController._handleInput(input: InputObject, processed: boolean)
    if processed then return end
    
    for actionName, keys in pairs(_actionMap) do
        for _, key in ipairs(keys) do
            if input.KeyCode == key or input.UserInputType == key then
                
                if input.UserInputState == Enum.UserInputState.Begin then
                    if not Character.CanPerform(actionName) then 
                        if Logger then Logger.debug("Input", `Ação {actionName} bloqueada pelo CharacterController`) end
                        return 
                    end

                    _activeActions[actionName] = os.clock()
                    InputController.ActionStarted:Fire(actionName)
                
                elseif input.UserInputState == Enum.UserInputState.End then
                    if _activeActions[actionName] then
                        local duration = os.clock() - _activeActions[actionName]
                        _activeActions[actionName] = nil
                        InputController.ActionEnded:Fire(actionName, duration)
                    end
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