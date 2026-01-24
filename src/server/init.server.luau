--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KernelConfig = require(ReplicatedStorage.Shared.Kernel.Config.KernelConfig)

local ServerBootstrap = require(script.Bootstrap.ServerBootstrap)
ServerBootstrap.init()

local NetworkKernel = require(game.ReplicatedStorage.Shared.Kernel.Network.NetworkKernel)
local Debugger = require(script.Debug.NetworkTest)

local Kernel = require(ReplicatedStorage.Shared.Kernel.Core)
local Data = Kernel.get("DataSystem") :: any

if not KernelConfig.DebugMode then return end
NetworkKernel.Init()
Debugger.Start()