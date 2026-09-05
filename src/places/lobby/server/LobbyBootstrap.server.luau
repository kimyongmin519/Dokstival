--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteRegistry = require(Shared.Net.RemoteRegistry)
local QueueService = require(script.Parent.QueueService)

local queueJoin = RemoteRegistry.get("QueueJoin") :: RemoteEvent
local queueLeave = RemoteRegistry.get("QueueLeave") :: RemoteEvent
local getQueueState = RemoteRegistry.get("GetQueueState") :: RemoteFunction

queueJoin.OnServerEvent:Connect(function(player: Player)
	QueueService.join(player)
end)
queueLeave.OnServerEvent:Connect(function(player: Player)
	QueueService.leave(player)
end)
getQueueState.OnServerInvoke = function(_player: Player)
	return QueueService.getSnapshot()
end

QueueService.start()
