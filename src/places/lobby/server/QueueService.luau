--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NetworkTypes = require(Shared.NetworkTypes)
local RemoteRegistry = require(Shared.Net.RemoteRegistry)

type QueueSnapshot = NetworkTypes.QueueSnapshot

local QueueService = {}
local queuedPlayers: { Player } = {}
local queuedByPlayer: { [Player]: boolean } = {}
local countdownToken = 0
local countdownEndsAt: number? = nil

local queueStateRemote = RemoteRegistry.get("QueueState") :: RemoteEvent
local queueErrorRemote = RemoteRegistry.get("QueueError") :: RemoteEvent

local function snapshot(): QueueSnapshot
	local userIds = {}
	for _, player in queuedPlayers do
		table.insert(userIds, player.UserId)
	end
	return {
		PlayerUserIds = userIds,
		PlayerCount = #queuedPlayers,
		MaximumPlayers = Config.Queue.MaximumPlayers,
		CountdownEndsAt = countdownEndsAt,
	}
end

local function broadcast(): ()
	queueStateRemote:FireAllClients(snapshot())
end

local function removePlayer(player: Player): ()
	if not queuedByPlayer[player] then
		return
	end
	queuedByPlayer[player] = nil
	local index = table.find(queuedPlayers, player)
	if index then
		table.remove(queuedPlayers, index)
	end
end

local function teleportQueue(): ()
	if #queuedPlayers < Config.Queue.MinimumPlayers then
		return
	end
	if Config.Places.Chapter1PlaceId <= 0 then
		warn("Chapter1PlaceId is not configured; skipping teleport")
		for _, player in queuedPlayers do
			queueErrorRemote:FireClient(player, "TeleportNotConfigured")
		end
		return
	end
	if RunService:IsStudio() then
		warn("Teleport is skipped in Studio; use a published multi-client test")
		for _, player in queuedPlayers do
			queueErrorRemote:FireClient(player, "TeleportSkippedInStudio")
		end
		return
	end

	local playersToTeleport = table.clone(queuedPlayers)
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	local success, teleportError = pcall(function()
		TeleportService:TeleportAsync(Config.Places.Chapter1PlaceId, playersToTeleport, options)
	end)
	if not success then
		warn(`Teleport failed: {tostring(teleportError)}`)
		for _, player in playersToTeleport do
			if player.Parent == Players then
				queueErrorRemote:FireClient(player, "TeleportFailed")
			end
		end
	end
end

local function beginCountdown(): ()
	if countdownEndsAt ~= nil or #queuedPlayers < Config.Queue.MinimumPlayers then
		return
	end
	countdownToken += 1
	local token = countdownToken
	countdownEndsAt = workspace:GetServerTimeNow() + Config.Queue.CountdownSeconds
	broadcast()
	task.delay(Config.Queue.CountdownSeconds, function()
		if token ~= countdownToken then
			return
		end
		countdownEndsAt = nil
		teleportQueue()
		broadcast()
	end)
end

function QueueService.join(player: Player): ()
	if queuedByPlayer[player] then
		return
	end
	if #queuedPlayers >= Config.Queue.MaximumPlayers then
		queueErrorRemote:FireClient(player, "QueueFull")
		return
	end
	queuedByPlayer[player] = true
	table.insert(queuedPlayers, player)
	broadcast()
	beginCountdown()
end

function QueueService.leave(player: Player): ()
	removePlayer(player)
	if #queuedPlayers < Config.Queue.MinimumPlayers and countdownEndsAt ~= nil then
		countdownToken += 1
		countdownEndsAt = nil
	end
	broadcast()
end

function QueueService.getSnapshot(): QueueSnapshot
	return snapshot()
end

function QueueService.start(): ()
	assert(RunService:IsServer(), "QueueService must run on the server")
	Players.PlayerRemoving:Connect(QueueService.leave)
end

return QueueService
