--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local CheckpointService = {}
local checkpointByPlayer: { [Player]: BasePart } = {}
local connectionsByCheckpoint: { [Instance]: RBXScriptConnection } = {}

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
	if connectionsByCheckpoint[instance] or not isValidCheckpoint(instance) then
		return
	end
	local checkpoint = instance :: BasePart
	connectionsByCheckpoint[checkpoint] = checkpoint.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			checkpointByPlayer[player] = checkpoint
		end
	end)
end

local function unregisterCheckpoint(instance: Instance): ()
	local connection = connectionsByCheckpoint[instance]
	if connection then
		connection:Disconnect()
		connectionsByCheckpoint[instance] = nil
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

local function onPlayerAdded(player: Player): ()
	player.CharacterAdded:Connect(function(character)
		moveToCheckpoint(player, character)
	end)
	if player.Character then
		task.spawn(moveToCheckpoint, player, player.Character)
	end
end

function CheckpointService.start(): ()
	for _, checkpoint in CollectionService:GetTagged(Config.Chapter.CheckpointTag) do
		registerCheckpoint(checkpoint)
	end
	CollectionService:GetInstanceAddedSignal(Config.Chapter.CheckpointTag):Connect(registerCheckpoint)
	CollectionService:GetInstanceRemovedSignal(Config.Chapter.CheckpointTag):Connect(unregisterCheckpoint)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		checkpointByPlayer[player] = nil
	end)
end

return CheckpointService
