--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kernel = require(ReplicatedStorage.Shared.Kernel.Core)
local Janitor = require(ReplicatedStorage.Shared.Kernel.Utils.Janitor)
local TweenUtils = require(ReplicatedStorage.Shared.Kernel.Utils.TweenUtils)
local ThreadManager = require(ReplicatedStorage.Shared.Kernel.Utils.ThreadManager)

local UIController = {}
local _janitor = Janitor.new()
local _uiJanitor = _janitor:Add(Janitor.new(), "Destroy")
local _views = {}
local _actions = {} 
local _activeTweens: { [Instance]: any } = {} 

local UI_CONFIG = {
    ANIM = {
        OPEN = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        CLOSE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        HOVER = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
    },
    INTERACTION = {
        SCALE_HOVER = 1.05,
        SCALE_CLICK = 0.95,
    },
    FALLBACKS = {
        HOVER_SOUND = "Hover",
        CLICK_SOUND = "Click",
    }
}

type ActionEvent = "Click" | "MouseEnter" | "MouseLeave"
local SUFFIXES = {"", "K", "M", "B", "T", "QD"}

function UIController.FormatNumber(value: number, mode: "Commas" | "Suffix"): string
    if mode == "Suffix" then
        local i = 1
        while value >= 1000 and i < #SUFFIXES do
            value /= 1000
            i += 1
        end
        return string.format("%.1f%s", value, SUFFIXES[i]):gsub("%.0", "")
    end

    local formatted = tostring(math.floor(value))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2') 
        if k == 0 then break end
    end
    return formatted
end

function UIController.FormatTime(seconds: number): string
    if seconds <= 0 then return "00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

function UIController.Typewriter(label: TextLabel | TextButton, text: string, speed: number?)
    local delayTime = speed or 0.05
    label.Text = ""
    ThreadManager.Spawn("Typewriter_" .. label:GetFullName(), function()
        for i = 1, #text do
            label.Text = string.sub(text, 1, i)
            task.wait(delayTime)
        end
    end)
end

function UIController.Tween(instance: Instance, target: {[string]: any}, info: TweenInfo?)
  
    if _activeTweens[instance] then
        _activeTweens[instance]:Destroy()
        _activeTweens[instance] = nil
    end

    local tweenInfo = info or UI_CONFIG.ANIM.HOVER 
    local newTween = TweenUtils.Play(instance, tweenInfo, target)
    
    _activeTweens[instance] = newTween

    local conn
    conn = instance.Destroying:Connect(function()
        if _activeTweens[instance] == newTween then
            newTween:Destroy()
            _activeTweens[instance] = nil
        end
        conn:Disconnect()
    end)

    return newTween
end

function UIController.BindAction(actionName: string, eventType: ActionEvent, callback: (button: GuiButton) -> ())
    if not _actions[actionName] then _actions[actionName] = {} end
    _actions[actionName][eventType] = callback
end

local function Trigger(actionName: string?, eventType: ActionEvent, button: GuiButton)
    if not actionName then return end
    local action = _actions[actionName]
    if action and action[eventType] then
        action[eventType](button)
    end
end


local function CreateButtonComponent(button: GuiButton, soundController: any)
    local bJanitor = Janitor.new()
    local originalSize = button.Size

    local hoverSnd = button:GetAttribute("HoverSound") or UI_CONFIG.FALLBACKS.HOVER_SOUND
    local clickSnd = button:GetAttribute("ClickSound") or UI_CONFIG.FALLBACKS.CLICK_SOUND
    
    local openTarget = button:GetAttribute("OpenUI")
    local closeTarget = button:GetAttribute("CloseUI")
    local actionName = button:GetAttribute("Action") or button.Name

    local function playAnim(scale: number)
        local targetSize = UDim2.fromScale(originalSize.X.Scale * scale, originalSize.Y.Scale * scale)
        UIController.Tween(button, {Size = targetSize}, UI_CONFIG.ANIM.HOVER)
    end

    bJanitor:Add(button.MouseEnter:Connect(function()
        playAnim(UI_CONFIG.INTERACTION.SCALE_HOVER)
        if soundController then soundController.PlaySFX(hoverSnd, {PitchVar = 0.05, Volume = 0.2}) end
        Trigger(actionName, "MouseEnter", button)
    end))

    bJanitor:Add(button.MouseLeave:Connect(function()
        playAnim(1)
        Trigger(actionName, "MouseLeave", button)
    end))

    bJanitor:Add(button.MouseButton1Down:Connect(function()
        playAnim(UI_CONFIG.INTERACTION.SCALE_CLICK)
    end))

    bJanitor:Add(button.MouseButton1Up:Connect(function()
        playAnim(UI_CONFIG.INTERACTION.SCALE_HOVER)
        if soundController then soundController.PlaySFX(clickSnd) end
        
        if openTarget then UIController.SetState(tostring(openTarget), true) end
        if closeTarget then UIController.SetState(tostring(closeTarget), false) end
        
        Trigger(actionName, "Click", button)
    end))

    bJanitor:Add(button.Destroying:Connect(function() 
        bJanitor:Destroy() 
    end))
end

function UIController.Register(frame: GuiObject)
    local name = frame.Name
    if _views[name] then return end

    _views[name] = {
        Instance = frame,
        Canvas = frame:FindFirstChildOfClass("CanvasGroup") or frame,
        Origin = frame.Position,
        Visible = false
    }
    frame.Visible = false
    
    if _views[name].Canvas:IsA("CanvasGroup") then
        _views[name].Canvas.GroupTransparency = 1
    end
end

function UIController.SetState(name: string, state: boolean)
    local view = _views[name]
    if not view or view.Visible == state then return end

    ThreadManager.Spawn("UI_" .. name, function()
        view.Visible = state
        local targetAlpha = state and 0 or 1
        local offset = UDim2.fromScale(0, 0.05)
        local targetPos = state and view.Origin or view.Origin + offset

        if state then
            view.Instance.Position = view.Origin + offset
            view.Instance.Visible = true
        end

        local tween = UIController.Tween(view.Canvas, {
            GroupTransparency = targetAlpha,
            Position = targetPos
        }, state and UI_CONFIG.ANIM.OPEN or UI_CONFIG.ANIM.CLOSE)

        if not state then
            tween:Then(function() 
                if not view.Visible then view.Instance.Visible = false end
            end)
        end
    end)
end

function UIController:Start(LoopService, Core)
    local sound = Core.expect("SoundController", 5)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local function bind(inst)
        if inst:IsA("GuiButton") and not inst:GetAttribute("Bound") then
            inst:SetAttribute("Bound", true)
            CreateButtonComponent(inst, sound)
        end
    end

    _uiJanitor:Add(playerGui.DescendantAdded:Connect(bind))
    for _, inst in ipairs(playerGui:GetDescendants()) do bind(inst) end

    for _, folder in ipairs(playerGui:GetChildren()) do
        if folder.Name == "Screens" or folder.Name == "Interactables" then
            for _, frame in ipairs(folder:GetChildren()) do
                if frame:IsA("GuiObject") then UIController.Register(frame) end
            end
        end
    end
end

return UIController