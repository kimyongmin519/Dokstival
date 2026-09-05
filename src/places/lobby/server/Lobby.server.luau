--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

type QueueSnapshot = {
	PlayerUserIds: { number },
	PlayerCount: number,
	MaximumPlayers: number,
	CountdownEndsAt: number?,
}

local queuedPlayers: { Player } = {}
local queuedByPlayer: { [Player]: boolean } = {}
local countdownToken = 0
local countdownEndsAt: number? = nil

local queueJoin = Remotes.get("QueueJoin") :: RemoteEvent
local queueLeave = Remotes.get("QueueLeave") :: RemoteEvent
local queueState = Remotes.get("QueueState") :: RemoteEvent
local queueError = Remotes.get("QueueError") :: RemoteEvent
local getQueueState = Remotes.get("GetQueueState") :: RemoteFunction

local function makeSnapshot(): QueueSnapshot
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

local function broadcastState(): ()
	queueState:FireAllClients(makeSnapshot())
end

local function teleportQueuedPlayers(): ()
	if #queuedPlayers < Config.Queue.MinimumPlayers then
		return
	end

	if Config.Places.Chapter1PlaceId <= 0 then
		warn("Chapter1PlaceId is not configured; skipping teleport")
		for _, player in queuedPlayers do
			queueError:FireClient(player, "TeleportNotConfigured")
		end
		return
	end

	-- TeleportService는 Studio에서 실제 Place 이동을 시험할 수 없습니다.
	if RunService:IsStudio() then
		warn("Teleport is skipped in Studio; use a published multi-client test")
		for _, player in queuedPlayers do
			queueError:FireClient(player, "TeleportSkippedInStudio")
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
				queueError:FireClient(player, "TeleportFailed")
			end
		end
	end
end

local function startCountdown(): ()
	if countdownEndsAt ~= nil or #queuedPlayers < Config.Queue.MinimumPlayers then
		return
	end

	countdownToken += 1
	local myToken = countdownToken
	countdownEndsAt = workspace:GetServerTimeNow() + Config.Queue.CountdownSeconds
	broadcastState()

	task.delay(Config.Queue.CountdownSeconds, function()
		-- 인원이 빠져 취소된 예전 타이머인지 확인합니다.
		if myToken ~= countdownToken then
			return
		end
		countdownEndsAt = nil
		teleportQueuedPlayers()
		broadcastState()
	end)
end

local function joinQueue(player: Player): ()
	if queuedByPlayer[player] then
		return
	end
	if #queuedPlayers >= Config.Queue.MaximumPlayers then
		queueError:FireClient(player, "QueueFull")
		return
	end

	queuedByPlayer[player] = true
	table.insert(queuedPlayers, player)
	broadcastState()
	startCountdown()
end

local function leaveQueue(player: Player): ()
	if not queuedByPlayer[player] then
		return
	end

	queuedByPlayer[player] = nil
	local index = table.find(queuedPlayers, player)
	if index then
		table.remove(queuedPlayers, index)
	end

	if #queuedPlayers < Config.Queue.MinimumPlayers and countdownEndsAt ~= nil then
		countdownToken += 1
		countdownEndsAt = nil
	end
	broadcastState()
end

-- 클라이언트는 요청만 보내고, 실제 큐 상태는 항상 서버가 결정합니다.
queueJoin.OnServerEvent:Connect(joinQueue)
queueLeave.OnServerEvent:Connect(leaveQueue)
getQueueState.OnServerInvoke = function(_player: Player)
	return makeSnapshot()
end
Players.PlayerRemoving:Connect(leaveQueue)
