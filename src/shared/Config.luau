--!strict

export type EnvironmentConfig = {
	LobbyPlaceId: number,
	Chapter1PlaceId: number,
	DataStoreName: string,
}

export type Config = {
	Environment: string,
	Places: EnvironmentConfig,
	Queue: {
		MinimumPlayers: number,
		MaximumPlayers: number,
		CountdownSeconds: number,
	},
	Chapter: {
		ActCount: number,
		CheckpointTag: string,
		CheckpointIdAttribute: string,
		CheckpointActAttribute: string,
	},
}

local environments: { [string]: EnvironmentConfig } = {
	Development = {
		LobbyPlaceId = 0,
		Chapter1PlaceId = 0,
		DataStoreName = "Dokstival_Development_v1",
	},
	Production = {
		LobbyPlaceId = 0,
		Chapter1PlaceId = 0,
		DataStoreName = "Dokstival_Production_v1",
	},
}

-- Change this value only when intentionally switching the synced Place environment.
local activeEnvironment = "Development"

local config: Config = {
	Environment = activeEnvironment,
	Places = environments[activeEnvironment],
	Queue = {
		MinimumPlayers = 1,
		MaximumPlayers = 4,
		CountdownSeconds = 15,
	},
	Chapter = {
		ActCount = 3,
		CheckpointTag = "ChapterCheckpoint",
		CheckpointIdAttribute = "CheckpointId",
		CheckpointActAttribute = "Act",
	},
}

return table.freeze(config)
