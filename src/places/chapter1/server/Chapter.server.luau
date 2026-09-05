--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

type ChapterSnapshot = { Act: number }

local currentAct = 1
local checkpointByPlayer: { [Player]: BasePart } = {}
local checkpointConnections: { [Instance]: RBXScriptConnection } = {}

local chapterState = Remotes.get("ChapterState") :: RemoteEvent
local getChapterState = Remotes.get("GetChapterState") :: RemoteFunction

local function makeChapterSnapshot(): ChapterSnapshot
	return { Act = currentAct }
end

local function setAct(nextAct: number): boolean
	if nextAct % 1 ~= 0 or nextAct < 1 or nextAct > Config.Chapter.ActCount then
		return false
	end
	if nextAct < currentAct then
		return false
	end

	currentAct = nextAct
	chapterState:FireAllClients(makeChapterSnapshot())
	return true
end

-- 나중에 퍼즐/목표가 끝나면 같은 서버 스크립트에서 이 함수를 호출합니다.
local function advanceAct(): boolean
	return setAct(currentAct + 1)
end

local function isValidCheckpoint(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		warn(`Tagged checkpoint {instance:GetFullName()} must be a BasePart`)
		return false
	end

	local checkpointId = instance:GetAttribute(Config.Chapter.CheckpointIdAttribute)
	local act = instance:GetAttribute(Config.Chapter.CheckpointActAttribute)
	if type(checkpointId) ~= "string" or checkpointId == "" then
		warn(`Checkpoint {instance:GetFullName()} needs a non-empty CheckpointId attribute`)
		return false
	end
	if type(act) ~= "number" or act % 1 ~= 0 or act < 1 or act > Config.Chapter.ActCount then
		warn(`Checkpoint {instance:GetFullName()} has an invalid Act attribute`)
		return false
	end
	return true
end

local function registerCheckpoint(instance: Instance): ()
	if checkpointConnections[instance] or not isValidCheckpoint(instance) then
		return
	end

	local checkpoint = instance :: BasePart
	checkpointConnections[checkpoint] = checkpoint.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if player then
			-- 서버 메모리에만 저장되므로 서버를 나가면 체크포인트도 사라집니다.
			checkpointByPlayer[player] = checkpoint
		end
	end)
end

local function unregisterCheckpoint(instance: Instance): ()
	local connection = checkpointConnections[instance]
	if connection then
		connection:Disconnect()
		checkpointConnections[instance] = nil
	end
end

local function moveToCheckpoint(player: Player, character: Model): ()
	local checkpoint = checkpointByPlayer[player]
	if not checkpoint or not checkpoint:IsDescendantOf(workspace) then
		return
	end

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		character:PivotTo(checkpoint.CFrame * CFrame.new(0, 4, 0))
	end
end

local function watchPlayer(player: Player): ()
	player.CharacterAdded:Connect(function(character)
		moveToCheckpoint(player, character)
	end)
	if player.Character then
		task.spawn(moveToCheckpoint, player, player.Character)
	end
end

getChapterState.OnServerInvoke = function(_player: Player)
	return makeChapterSnapshot()
end

for _, checkpoint in CollectionService:GetTagged(Config.Chapter.CheckpointTag) do
	registerCheckpoint(checkpoint)
end
CollectionService:GetInstanceAddedSignal(Config.Chapter.CheckpointTag):Connect(registerCheckpoint)
CollectionService:GetInstanceRemovedSignal(Config.Chapter.CheckpointTag):Connect(unregisterCheckpoint)

for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	checkpointByPlayer[player] = nil
end)
