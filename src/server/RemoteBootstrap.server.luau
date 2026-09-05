--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

-- Remote는 서버만 생성합니다. 클라이언트가 임의로 만든 Remote는 신뢰하지 않습니다.
Remotes.createAll()
