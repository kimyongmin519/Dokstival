--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteDefinitions = require(script.Parent.RemoteDefinitions)

type RemoteDefinition = RemoteDefinitions.RemoteDefinition

local RemoteRegistry = {}

local function getDefinition(key: string): RemoteDefinition
	local definition = RemoteDefinitions.Definitions[key]
	assert(definition ~= nil, `Unknown remote key: {key}`)
	return definition
end

function RemoteRegistry.createAll(): Folder
	assert(RunService:IsServer(), "Only the server may create remotes")

	local existing = ReplicatedStorage:FindFirstChild(RemoteDefinitions.FolderName)
	local folder: Folder
	if existing then
		assert(existing:IsA("Folder"), "ReplicatedStorage.Remotes must be a Folder")
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = RemoteDefinitions.FolderName
		folder.Parent = ReplicatedStorage
	end

	for _, definition in RemoteDefinitions.Definitions do
		local remote = folder:FindFirstChild(definition.Name)
		if remote then
			assert(remote.ClassName == definition.Kind, `{definition.Name} has an unexpected class`)
		else
			remote = Instance.new(definition.Kind)
			remote.Name = definition.Name
			remote.Parent = folder
		end
	end

	return folder
end

function RemoteRegistry.get(key: string): RemoteEvent | RemoteFunction
	local definition = getDefinition(key)
	local folder = ReplicatedStorage:WaitForChild(RemoteDefinitions.FolderName)
	local remote = folder:WaitForChild(definition.Name)
	assert(remote.ClassName == definition.Kind, `{definition.Name} has an unexpected class`)
	return remote :: RemoteEvent | RemoteFunction
end

return table.freeze(RemoteRegistry)
