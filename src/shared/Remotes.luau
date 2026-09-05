--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- 모든 Remote 이름과 종류는 여기서만 정합니다.
-- 서버가 createAll()로 만들고, 클라이언트는 get()으로 기다렸다가 사용합니다.
local remoteClasses: { [string]: "RemoteEvent" | "RemoteFunction" } = {
	QueueJoin = "RemoteEvent",
	QueueLeave = "RemoteEvent",
	QueueState = "RemoteEvent",
	QueueError = "RemoteEvent",
	GetQueueState = "RemoteFunction",
	ChapterState = "RemoteEvent",
	GetChapterState = "RemoteFunction",
}

local Remotes = {}
local FOLDER_NAME = "Remotes"

function Remotes.createAll(): ()
	assert(RunService:IsServer(), "Only the server may create remotes")

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	local folder: Folder
	if existing then
		assert(existing:IsA("Folder"), "ReplicatedStorage.Remotes must be a Folder")
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for name, className in remoteClasses do
		local remote = folder:FindFirstChild(name)
		if remote then
			assert(remote.ClassName == className, `{name} has an unexpected class`)
		else
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name: string): RemoteEvent | RemoteFunction
	local className = remoteClasses[name]
	assert(className ~= nil, `Unknown remote: {name}`)

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name)
	assert(remote.ClassName == className, `{name} has an unexpected class`)
	return remote :: RemoteEvent | RemoteFunction
end

return table.freeze(Remotes)
