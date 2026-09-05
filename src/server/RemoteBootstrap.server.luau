--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteRegistry = require(Shared.Net.RemoteRegistry)

RemoteRegistry.createAll()
