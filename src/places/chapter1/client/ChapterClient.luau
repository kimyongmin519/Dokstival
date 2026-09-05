--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkTypes = require(Shared.NetworkTypes)
local RemoteRegistry = require(Shared.Net.RemoteRegistry)

type ChapterSnapshot = NetworkTypes.ChapterSnapshot

local ChapterClient = {}

function ChapterClient.getState(): ChapterSnapshot
	return (RemoteRegistry.get("GetChapterState") :: RemoteFunction):InvokeServer() :: ChapterSnapshot
end

function ChapterClient.onStateChanged(callback: (ChapterSnapshot) -> ()): RBXScriptConnection
	return (RemoteRegistry.get("ChapterState") :: RemoteEvent).OnClientEvent:Connect(callback)
end

return table.freeze(ChapterClient)
