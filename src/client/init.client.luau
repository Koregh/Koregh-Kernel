--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientBootstrap = require(script.Bootstrap.ClientBootstrap)
ClientBootstrap.init()

local KernelConfig = require(ReplicatedStorage.Shared.Kernel.Config.KernelConfig)

if not KernelConfig.DebugMode then return end

local NetworkKernel = require(game.ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)
local Debugger = require(script.Debug.NetworkTest) 

NetworkKernel.Init()
Debugger.Start()    

local SoundController = require(script.Controllers.SoundController)
SoundController.PlayMusic("Started",false)

