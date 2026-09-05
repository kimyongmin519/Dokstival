--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NetworkTypes = require(Shared.NetworkTypes)
local RemoteRegistry = require(Shared.Net.RemoteRegistry)

type QueueSnapshot = NetworkTypes.QueueSnapshot

local QueueClient = {}

function QueueClient.join(): ()
	(RemoteRegistry.get("QueueJoin") :: RemoteEvent):FireServer()
end

function QueueClient.leave(): ()
	(RemoteRegistry.get("QueueLeave") :: RemoteEvent):FireServer()
end

function QueueClient.getState(): QueueSnapshot
	return (RemoteRegistry.get("GetQueueState") :: RemoteFunction):InvokeServer() :: QueueSnapshot
end

function QueueClient.onStateChanged(callback: (QueueSnapshot) -> ()): RBXScriptConnection
	return (RemoteRegistry.get("QueueState") :: RemoteEvent).OnClientEvent:Connect(callback)
end

function QueueClient.onError(callback: (string) -> ()): RBXScriptConnection
	return (RemoteRegistry.get("QueueError") :: RemoteEvent).OnClientEvent:Connect(callback)
end

return table.freeze(QueueClient)
