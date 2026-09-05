--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

export type ChapterSnapshot = { Act: number }

local ChapterClient = {}

function ChapterClient.getState(): ChapterSnapshot
	return (Remotes.get("GetChapterState") :: RemoteFunction):InvokeServer() :: ChapterSnapshot
end

function ChapterClient.onStateChanged(callback: (ChapterSnapshot) -> ()): RBXScriptConnection
	return (Remotes.get("ChapterState") :: RemoteEvent).OnClientEvent:Connect(callback)
end

return table.freeze(ChapterClient)
