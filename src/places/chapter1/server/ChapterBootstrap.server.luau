--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteRegistry = require(Shared.Net.RemoteRegistry)
local ChapterStateService = require(script.Parent.ChapterStateService)
local CheckpointService = require(script.Parent.CheckpointService)

local getChapterState = RemoteRegistry.get("GetChapterState") :: RemoteFunction
getChapterState.OnServerInvoke = function(_player: Player)
	return ChapterStateService.getSnapshot()
end

CheckpointService.start()
