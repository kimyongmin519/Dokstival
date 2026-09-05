--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

export type QueueSnapshot = {
	PlayerUserIds: { number },
	PlayerCount: number,
	MaximumPlayers: number,
	CountdownEndsAt: number?,
}

local QueueClient = {}

function QueueClient.join(): ()
	(Remotes.get("QueueJoin") :: RemoteEvent):FireServer()
end

function QueueClient.leave(): ()
	(Remotes.get("QueueLeave") :: RemoteEvent):FireServer()
end

function QueueClient.getState(): QueueSnapshot
	return (Remotes.get("GetQueueState") :: RemoteFunction):InvokeServer() :: QueueSnapshot
end

function QueueClient.onStateChanged(callback: (QueueSnapshot) -> ()): RBXScriptConnection
	return (Remotes.get("QueueState") :: RemoteEvent).OnClientEvent:Connect(callback)
end

function QueueClient.onError(callback: (string) -> ()): RBXScriptConnection
	return (Remotes.get("QueueError") :: RemoteEvent).OnClientEvent:Connect(callback)
end

return table.freeze(QueueClient)
