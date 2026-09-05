--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NetworkTypes = require(Shared.NetworkTypes)
local RemoteRegistry = require(Shared.Net.RemoteRegistry)

type ChapterSnapshot = NetworkTypes.ChapterSnapshot

local ChapterStateService = {}
local currentAct = 1
local chapterStateRemote = RemoteRegistry.get("ChapterState") :: RemoteEvent

function ChapterStateService.getSnapshot(): ChapterSnapshot
	return { Act = currentAct }
end

function ChapterStateService.setAct(act: number): boolean
	if act % 1 ~= 0 or act < 1 or act > Config.Chapter.ActCount then
		return false
	end
	if act < currentAct then
		return false
	end
	currentAct = act
	chapterStateRemote:FireAllClients(ChapterStateService.getSnapshot())
	return true
end

function ChapterStateService.advance(): boolean
	return ChapterStateService.setAct(currentAct + 1)
end

return ChapterStateService
